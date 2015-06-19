-----------------------------------------------------------------------------------------------
-- Client Lua Script for ZoneCompletion
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "PlayerPathLib"
require "Apollo"

local ZoneCompletion = {}

local ktIcons =
{
	[GameLib.CodeEnumZoneCompletionType.EpisodeQuest]	= 	"CRB_MegamapSprites:sprMap_IconCompletion_EpisodeQuest",
	[GameLib.CodeEnumZoneCompletionType.TaskQuest]		=	"CRB_MegamapSprites:sprMap_IconCompletion_TaskQuest",
	[GameLib.CodeEnumZoneCompletionType.Challenge]		=	"CRB_MegamapSprites:sprMap_IconCompletion_Challenge",
	[GameLib.CodeEnumZoneCompletionType.Datacube]		=	"CRB_MegamapSprites:sprMap_IconCompletion_Datacube",
	[GameLib.CodeEnumZoneCompletionType.Tale]			=	"CRB_MegamapSprites:sprMap_IconCompletion_Tales",
	[GameLib.CodeEnumZoneCompletionType.Journal]		=	"CRB_MegamapSprites:sprMap_IconCompletion_Lore",
	["PercentExplored"]									=	"CRB_MegamapSprites:sprMap_IconCompletion_MapExplored",
}

local ktPathString =
{
	[PlayerPathLib.PlayerPathType_Soldier]		=	Apollo.GetString("CRB_Soldier"),
	[PlayerPathLib.PlayerPathType_Scientist]	=	Apollo.GetString("CRB_Scientist"),
	[PlayerPathLib.PlayerPathType_Explorer]		=	Apollo.GetString("CRB_Explorer"),
	[PlayerPathLib.PlayerPathType_Settler]		=	Apollo.GetString("CRB_Settler"),
}

local ktPathIcon =
{
	[PlayerPathLib.PlayerPathType_Soldier]		=	"CRB_MegamapSprites:sprMap_IconCompletion_Soldier",
	[PlayerPathLib.PlayerPathType_Scientist]	=	"CRB_MegamapSprites:sprMap_IconCompletion_Scientist",
	[PlayerPathLib.PlayerPathType_Explorer]		=	"CRB_MegamapSprites:sprMap_IconCompletion_Explorer",
	[PlayerPathLib.PlayerPathType_Settler]		=	"CRB_MegamapSprites:sprMap_IconCompletion_Settler",
}

function ZoneCompletion:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ZoneCompletion:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	local tSavedData = {}
	tSavedData.bMaximized = self.bMaximized
	return tSavedData
end

function ZoneCompletion:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	self.bMaximized = tSavedData.bMaximized
end

function ZoneCompletion:Init()
    Apollo.RegisterAddon(self)
end

function ZoneCompletion:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ZoneCompletion.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ZoneCompletion:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterTimerHandler("ZoneCompletion_UpdateWindowTimer", "RedrawAll", self)
	Apollo.RegisterEventHandler("GenericEvent_OpenZoneCompletion", "OnShow", self)
	Apollo.RegisterEventHandler("GenericEvent_CloseZoneCompletion", "OnClose", self)
	Apollo.RegisterEventHandler("GenericEvent_MinimizeZoneCompletion", "OnMinimized", self)
	Apollo.RegisterEventHandler("GenericEvent_OpenZoneCompletion", "OnOpened", self)
	Apollo.RegisterEventHandler("GenericEvent_ZoneMap_ZoneChanged", "OnZoneChanged", self)
	Apollo.RegisterEventHandler("GenericEvent_ZoneMap_ZoomLevelChanged", "OnZoomLevelChanged", self)
	Apollo.RegisterEventHandler("GenericEvent_ZoneMap_SetMapCompletionShown", "OnSetMapCompletionShown", self)
	
	Apollo.CreateTimer("ZoneCompletion_UpdateWindowTimer", 1, true)
	Apollo.StopTimer("ZoneCompletion_UpdateWindowTimer")

	self.wndMain = nil
	self.bWasIOpen = false
end

function ZoneCompletion:OnClose(wndHandler, wndControl)
	Apollo.StopTimer("ZoneCompletion_UpdateWindowTimer")
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMinimizeToggle:Destroy()
		self.wndMinimizeToggle = nil
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function ZoneCompletion:OnMinimized(wndHandler, wndControl)
	if self.wndMinimizeToggle and self.wndMinimizeToggle:IsValid() then
		if self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):IsChecked() then
			self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):SetCheck(false)
			self.bWasIOpen = true
		else
			self.OnClose(self)
			self.bWasIOpen = false
		end
	end
end

function ZoneCompletion:OnOpened(wndHandler, wndControl)
	if self.bWasIOpen and self.wndMinimizeToggle and self.wndMinimizeToggle:IsValid() then
		self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):SetCheck(true)
		self.bWasIOpen = false
	end
	--Scale Left Window
	local nLeft2, nTop2, nRight2, nBottom2 = self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):GetAnchorOffsets()
	
	if self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):IsChecked() then
		self.wndMinimizeToggle:FindChild("GrabberFrame"):Show(false)
		self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):SetAnchorOffsets(216, nTop2, 269, nBottom2)
	else
		self.wndMinimizeToggle:FindChild("GrabberFrame"):Show(true)
		self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):SetAnchorOffsets(-1, nTop2, 52, nBottom2)
	end
	
end

function ZoneCompletion:OnShow(wndParent)
	-- One time initialize
	if not self.ePlayerPath then
		self.sZoneWeAreWatching = nil
		self.ePlayerPath = PlayerPathLib.GetPlayerPathType()
		self.arZoneList = GameLib.GetAllZoneCompletionMapZones()

		self.arCompletionTypes = {}
		for idx, tType in ipairs(GameLib.GetZoneCompletionTypes()) do
			self.arCompletionTypes[tType.nTypeEnum] = tType.strTypeName
		end
	end

	-- Window initialize can happen multiple times
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "ZoneCompletionWindow", wndParent, self)
		self.wndMinimizeToggle = Apollo.LoadForm(self.xmlDoc, "ZoneCompletionMinimizeToggle", wndParent, self)
		self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):AttachWindow(self.wndMain)
		self.wndMain:FindChild("WorldCompletionProgressBar"):SetMax(100)
	end

	local tCurrentZone = GameLib.GetCurrentZoneMap()
	self.wndMain:SetData(tCurrentZone and tCurrentZone.id or 0)
	self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):SetCheck(self.bMaximized)
	
	Apollo.StartTimer("ZoneCompletion_UpdateWindowTimer")
end

function ZoneCompletion:OnZoneChanged(nZoneId)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:SetData(nZoneId)
		if self.wndMain:IsShown() then
			self:RedrawAll()
		end
	end
end

function ZoneCompletion:OnZoomLevelChanged(bValidZoneZoom)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("ZoneCompletionFrame"):Show(bValidZoneZoom)
		if self.wndMain:IsShown() then
			self:RedrawAll()
		end
	end
end

function ZoneCompletion:OnSetMapCompletionShown(bToggle)
	if self.wndMinimizeToggle and self.wndMinimizeToggle:IsValid() then
		self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):SetCheck(bToggle)
	end
end

function ZoneCompletion:RedrawFromUI(wndHandler, wndControl)
	self:RedrawAll()
end

function ZoneCompletion:RedrawAll() -- Also from GenericEvent_ZoneMap_ZoneChanged and XML	
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then
		Apollo.StopTimer("ZoneCompletion_UpdateWindowTimer")
		return
	end

	-- Set World Progress Bar
	local nWorldPercent = GameLib.GetWorldCompletionPercent()
	self.wndMain:FindChild("WorldCompletionProgressBar"):SetProgress(nWorldPercent)
	self.wndMain:FindChild("WorldCompletionProgText"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Percent"), nWorldPercent))
	self.wndMain:FindChild("CountsContainer"):DestroyChildren()

	-- Zone Count Items (if valid)
	local nZoneId = self.wndMain:GetData() or 0
	local tZoneCompletion = GameLib.GetZoneCompletion(nZoneId)
	if tZoneCompletion then
		-- Build list of data
		local tLocalZoneValues = {}
		for idx, tCurrZoneValue in pairs(tZoneCompletion.tZoneValues) do
			tLocalZoneValues[idx - 1] = tCurrZoneValue
		end

		-- EpisodeQuest, TaskQuest, Challenge, TaxiNode, Datacube, Tale, Journal
		for idx, nIndex in pairs(GameLib.CodeEnumZoneCompletionType) do
			local nComplete, nGoal = self:HelperBuildCountItem(tLocalZoneValues, nIndex)
		end

		-- Path special window
		for idx, tZoneEntry in pairs(self.arZoneList or {}) do
			if tZoneEntry.nWorldZoneId ~= 0 and tZoneEntry.nMapZoneId == nZoneId then
				self:HelperBuildPathCountItem(tZoneCompletion.tPathValues)
			end
		end

		-- Explore % special window
		if tZoneCompletion.tExplorationValues and not tZoneCompletion.tExplorationValues.bHideExploration then
			self:HelperBuildPercentExploredItem(tZoneCompletion.tExplorationValues.nPercent)
		end

		self.wndMain:FindChild("ZoneCompletionProgressBar"):SetMax(tZoneCompletion.tOverallValues.nGoal)
		self.wndMain:FindChild("ZoneCompletionProgressBar"):SetProgress(tZoneCompletion.tOverallValues.nComplete)
		self.wndMain:FindChild("ZoneCompletionProgText"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Percent"), tZoneCompletion.tOverallValues.nPercent))
		self.wndMain:FindChild("ZoneCompletionTitle"):SetText(tZoneCompletion.strZoneName)
	else
		self.wndMain:FindChild("ZoneCompletionFrame"):Show(false) -- GOTCHA: Valid doesn't necessarily mean true, as it could be zoomed out
	end

	-- Resize
	local nHeight = self.wndMain:FindChild("WorldCompletionFrame"):GetHeight() * 2
	if self.wndMain:FindChild("ZoneCompletionFrame"):IsVisible() then
		nHeight = nHeight + self.wndMain:FindChild("CountsContainer"):ArrangeChildrenVert(0)
	end
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 100)
	
end

function ZoneCompletion:HelperBuildCountItem(tLocalZoneValues, nIndex)
	local nComplete = tLocalZoneValues[nIndex].nComplete
	local nGoal = tLocalZoneValues[nIndex].nGoal or 0

	if nComplete and nGoal and nGoal > 0 then
		local wndCount = Apollo.LoadForm(self.xmlDoc, "CountItem", self.wndMain:FindChild("CountsContainer"), self)
		local strTitle = string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ff31fcf6\">%s</P>", String_GetWeaselString(Apollo.GetString("CRB_Colon"), self.arCompletionTypes[nIndex]))
		local strCount = string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ffffffff\">%s</P>", String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nComplete, nGoal))
		wndCount:FindChild("CountQuestText"):SetText(String_GetWeaselString(Apollo.GetString("ZoneCompletion_TitleCount"), strTitle, strCount))
		wndCount:FindChild("CountItemIcon"):SetSprite(ktIcons[nIndex])
	end

	return nComplete, nGoal
end

function ZoneCompletion:HelperBuildPercentExploredItem(nPercent)
	local wndCount = Apollo.LoadForm(self.xmlDoc, "CountItem", self.wndMain:FindChild("CountsContainer"), self)
	local strTitle = string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ff31fcf6\">%s</P>", Apollo.GetString("ZoneCompletion_Explored"))
	local strCount = string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ffffffff\">%s</P>", String_GetWeaselString(Apollo.GetString("CRB_Percent"), nPercent))
	wndCount:FindChild("CountQuestText"):SetText(String_GetWeaselString(Apollo.GetString("ZoneCompletion_TitleCount"), strTitle, strCount))
	wndCount:FindChild("CountItemIcon"):SetSprite(ktIcons["PercentExplored"])
end

function ZoneCompletion:HelperBuildPathCountItem(tPathValues)
	if not tPathValues then
		return
	end

	local nTotal = tPathValues.nGoal
	local nComplete = tPathValues.nComplete

	if nTotal > 0 then
		local wndPath = Apollo.LoadForm(self.xmlDoc, "CountItem", self.wndMain:FindChild("CountsContainer"), self)
		wndPath:FindChild("CountItemIcon"):SetSprite(ktPathIcon[self.ePlayerPath] or "")
		
		local strTitle = string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ff31fcf6\">%s</P>", String_GetWeaselString(Apollo.GetString("CRB_Colon"), ktPathString[self.ePlayerPath]))
		local strCount = string.format("<P Font=\"CRB_InterfaceSmall_O\" TextColor=\"ffffffff\">%s</P>", String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nComplete, nTotal))
		wndPath:FindChild("CountQuestText"):SetText(String_GetWeaselString(Apollo.GetString("ZoneCompletion_TitleCount"), strTitle, strCount))
	end
end

function ZoneCompletion:OnMinimizeToggle(wndHandler, wndControl)
	self.bMaximized = self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):IsChecked()
	
	--Scale Left Window
	local nLeft2, nTop2, nRight2, nBottom2 = self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):GetAnchorOffsets()
	
	if self.bMaximized then
		self.wndMinimizeToggle:FindChild("GrabberFrame"):Show(false)
		self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):SetAnchorOffsets(216, nTop2, 269, nBottom2)
	else
		self.wndMinimizeToggle:FindChild("GrabberFrame"):Show(true)
		self.wndMinimizeToggle:FindChild("ZoneCompletionMinimizeToggleBtn"):SetAnchorOffsets(-1, nTop2, 52, nBottom2)
	end
end

local ZoneCompletionInst = ZoneCompletion:new()
ZoneCompletionInst:Init()
