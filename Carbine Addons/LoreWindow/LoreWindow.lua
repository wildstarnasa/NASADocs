-----------------------------------------------------------------------------------------------
-- Client Lua Script for LoreWindow
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "DatacubeLib"

local LoreWindow = {}

local bDockedOption = false
local kclrDefault = "ff62aec1"

local karContinents =
{
	Apollo.GetString("CRB_Eastern"),
	Apollo.GetString("CRB_Western"),
	Apollo.GetString("CRB_Central"),
	Apollo.GetString("Lore_Offworld"),
	Apollo.GetString("CRB_Dungeons"),
	Apollo.GetString("Lore_DefaultZone") -- TODO TEMP REMOVE
}

local ktZoneNameToContinent =  -- TODO TEMP
{
	[Apollo.GetString("Lore_Algoroc")] 						= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_Celestion")] 					= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_EverstarGrove")]				= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_Galeras")] 						= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_Murkmire")] 					= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_NorthernWilds")] 				= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_Whitevale")]					= Apollo.GetString("CRB_Eastern"),
	[Apollo.GetString("Lore_Thayd")]						= Apollo.GetString("CRB_Eastern"),

	[Apollo.GetString("Lore_Datascape")] 					= Apollo.GetString("CRB_Dungeons"),
	[Apollo.GetString("Lore_KelVoreth")] 					= Apollo.GetString("CRB_Dungeons"),
	[Apollo.GetString("Lore_SwordMaiden")] 					= Apollo.GetString("CRB_Dungeons"),
	[Apollo.GetString("Lore_Skullcano")] 					= Apollo.GetString("CRB_Dungeons"),
	[Apollo.GetString("Lore_Stormtalon")] 					= Apollo.GetString("CRB_Dungeons"),
	[Apollo.GetString("Lore_Simulations")] 					= Apollo.GetString("CRB_Dungeons"),

	[Apollo.GetString("Lore_Grimvault")] 					= Apollo.GetString("CRB_Central"),
	[Apollo.GetString("Lore_NMalgrave")] 					= Apollo.GetString("CRB_Central"), -- TODO: Remove string
	[Apollo.GetString("Lore_SMalgrave")] 					= Apollo.GetString("CRB_Central"), -- TODO: Remove string
	[Apollo.GetString("Lore_Malgrave")] 					= Apollo.GetString("CRB_Central"),
	[Apollo.GetString("Lore_NGrimvault")] 					= Apollo.GetString("CRB_Central"),
	[Apollo.GetString("Lore_SGrimvault")] 					= Apollo.GetString("CRB_Central"),
	[Apollo.GetString("Lore_WGrimvault")] 					= Apollo.GetString("CRB_Central"),
	[Apollo.GetString("Lore_TheDefile")] 					= Apollo.GetString("CRB_Central"),

	[Apollo.GetString("Lore_Auroria")] 						= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_CrimsonIsle")] 					= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_Deradune")] 					= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_Dreadmoor")] 					= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_Ellevar")] 						= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_Illium")] 						= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_LeviathanBay")] 				= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_LevianBay")] 					= Apollo.GetString("CRB_Western"),
	[Apollo.GetString("Lore_Wilderrun")] 					= Apollo.GetString("CRB_Western"),

	[Apollo.GetString("Lore_DominionArkship")] 				= Apollo.GetString("Lore_Offworld"), -- TODO: Remove String
	[Apollo.GetString("Lore_ExileArkship")] 				= Apollo.GetString("Lore_Offworld"), -- TODO: Remove String
	[Apollo.GetString("Lore_TheDestiny")] 					= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_GamblersRuin")] 				= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_Infestation")] 					= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_Farside")] 						= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_Graylight")] 					= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_HalonRing")] 					= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_ShiphandMissions")] 			= Apollo.GetString("Lore_Offworld"),
	[Apollo.GetString("Lore_ShiphandInfestation")] 			= Apollo.GetString("Lore_Offworld"),
}

function LoreWindow:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function LoreWindow:Init()
    Apollo.RegisterAddon(self)
end

function LoreWindow:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("LoreWindow.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function LoreWindow:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 		"OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 		"OnTutorial_RequestUIAnchor", self)

	Apollo.RegisterSlashCommand("compactlore", 						"OnCompactLore", self)
	Apollo.RegisterEventHandler("DatacubeUpdated", 					"OnDatacubeUpdated", self)
	Apollo.RegisterEventHandler("HudAlert_ToggleLoreWindow", 		"OnShowLoreWindow", self)
    Apollo.RegisterEventHandler("InterfaceMenu_ToggleLoreWindow", 	"OnToggleLoreWindow", self)

	Apollo.RegisterEventHandler("DatacubePlaybackEnded",			"OnDatacubeStopped", self)
	Apollo.RegisterEventHandler("GenericEvent_StopPlayingDatacube", "OnDatacubeStopped", self)

	-- used to make sure that the datachron can't be replayed while its still fading out
	self.timerDatacubeStopping = ApolloTimer.Create(4.000, false, "OnDatacubeTimer", self)
	self.timerDatacubeStopping:Stop()

	self.tNewEntries = {} -- Start tracking right away
end

function LoreWindow:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Lore"), {"InterfaceMenu_ToggleLoreWindow", "Lore", "Icon_Windows32_UI_CRB_InterfaceMenu_Lore"})
end

function LoreWindow:Initialize()
	self.wndColDisplay = nil
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "LoreWindowForm", nil, self)
	self.wndColMainScroll = self.wndMain:FindChild("ColMainScroll")
	self.wndMainNavGA = self.wndMain:FindChild("MainNavGA")
	self.wndMainNavCol = self.wndMain:FindChild("MainNavCol")
	self.wndColTopDropdownScroll = self.wndMain:FindChild("ColTopDropdownScroll")
	self.wndColTopZoneProgressContainer = self.wndMain:FindChild("ColTopZoneProgressContainer")
	self.wndColTopDropdownBtn = self.wndMain:FindChild("ColTopDropdownBtn")
	self.wndMainArticleContainer = self.wndMain:FindChild("MainArticleContainer")

	local wndMainGAContainer = self.wndMain:FindChild("MainGAContainer")
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("InterfaceMenu_Lore")})

	self.wndMainNavGA:AttachWindow(wndMainGAContainer)
	self.wndMainNavCol:AttachWindow(self.wndMain:FindChild("MainColContainer"))

	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "ColHeader", nil, self)
	self.knWndHeaderDefaultHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "ColJournalItem", nil, self)
	self.knWndJournalItemDefaultHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	Event_FireGenericEvent("ToggleGalacticArchiveWindow", wndMainGAContainer, self.wndMain)

	self.wndColTopDropdownBtn:AttachWindow(self.wndMain:FindChild("ColTopDropdownBG"))
	self:InitializeCollections() -- Replace with a Generic Event if we pull this out of this file
end

function LoreWindow:OnDatacubeUpdated(idArg, bIsVolume)
	if idArg then
		local tDatacube = DatacubeLib.GetLastUpdatedDatacube(idArg, bIsVolume) -- Nothing until it's unlocked anyways
		if not tDatacube then
			return
		end

		local bPartialTales = tDatacube.eDatacubeType == DatacubeLib.DatacubeType_Chronicle and not tDatacube.bIsComplete
		if not bPartialTales then
			self.tNewEntries[tDatacube.nDatacubeId] = true -- GOTCHA: tDatacube.id can be different than nArgId (when nArgId is a volume)
		end
	end

	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsShown() then
		self.wndColMainScroll:DestroyChildren()
		self:MainRedrawCollections()

		-- Update dropdown
		for key, wndCurr in pairs(self.wndColTopDropdownScroll:GetChildren()) do
			if wndCurr:FindChild("DropdownZoneBtn") then
				local tCurrZone = wndCurr:FindChild("DropdownZoneBtn"):GetData()
				self:HelperDrawDropdownZoneProgress(wndCurr, tCurrZone.nZoneId, tCurrZone.strName)
			end
		end

		-- Update the selected zone total progress
		local wndColTopDropdownBtn = self.wndMain:FindChild("MainColContainer:ColTopBG:ColTopDropdownBtn")
		if wndColTopDropdownBtn ~= nil then
			local tSelectedZoneData = wndColTopDropdownBtn:GetData()
			if tSelectedZoneData ~= nil then
				self:HelperDrawDropdownZoneProgress(self.wndMain:FindChild("MainColContainer:ColTopBG:ColTopZoneProgressContainer"), tSelectedZoneData.nZoneId, tSelectedZoneData.strName)
			end
		end
	end
end

function LoreWindow:OnShowLoreWindow(tArticleData)
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize()
	end

	self.wndMain:Invoke()
	Event_ShowTutorial(GameLib.CodeEnumTutorial.General_Lore)
	
	self.wndMain:FindChild("MainColContainer:PvPBlocker"):Show(MatchingGame.IsInPVPGame())

	if tArticleData then
		self:OpenToSpecificArticle(tArticleData.nDatacubeId)
	end
end

function LoreWindow:OnToggleLoreWindow(tArticleData)
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize()
	end

	if self.wndMain:IsShown() then
		self:OnCloseBtn()
		Event_FireGenericEvent("LoreWindowHasBeenClosed")
		
	else
		self:OnShowLoreWindow()
		Event_FireGenericEvent("LoreWindowHasBeenToggled")
		Event_ShowTutorial(GameLib.CodeEnumTutorial.General_Lore)
	end

	if tArticleData then
		self:OpenToSpecificArticle(tArticleData.nDatacubeId)
	end
end

function LoreWindow:OpenToSpecificArticle(idArg, bIsVolume)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	-- Assume we'll be on the right zone page (or just don't care)
	local tArticleData = DatacubeLib.GetLastUpdatedDatacube(idArg, bIsVolume)
	self.wndMainNavGA:SetCheck(false)
	self.wndMainNavCol:SetCheck(true)
	self:SpawnAndDrawColReader(tArticleData, nil)
	self.wndColDisplay:FindChild("PlayPauseButton"):SetCheck(true)

	-- Try to find the correct wndOrigin (TODO HACKY)
	local wndOrigin = nil
	if tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Chronicle then
		local wndParent = self.wndColMainScroll:FindChildByUserData("Tales"..idArg)
		if wndParent then
			wndParent:FindChild("ColTalesBtn"):SetCheck(true)
			self.wndColDisplay:SetData(wndParent:FindChild("ColTalesBtn"))
		end
	elseif tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Journal then
		local wndParent = self.wndColMainScroll:FindChildByUserData("JournalArticle"..idArg)
		if wndParent then
			wndParent:FindChild("ColJournalChildBtn"):SetCheck(true)
			self.wndColDisplay:SetData(wndParent:FindChild("ColJournalChildBtn"))
		end
	elseif tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Datacube then
		local wndParent = self.wndColMainScroll:FindChildByUserData("Datacube"..idArg)
		if wndParent then
			wndParent:FindChild("ColDatacubeBtn"):SetCheck(true)
			self.wndColDisplay:SetData(wndParent:FindChild("ColDatacubeBtn"))
		end
	end
end

function LoreWindow:OnCloseBtn(wndHandler, wndControl)
	self:OnDestroyColDisplay()
	Event_FireGenericEvent("GenericEvent_CloseGAReader")
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

-----------------------------------------------------------------------------------------------
-- Formerly Collections
-----------------------------------------------------------------------------------------------

function LoreWindow:InitializeCollections()
	-- Build zone dropdown
	local tZonesAtLoad = {}
	for key, tCurrZone in pairs(DatacubeLib.GetZonesWithDatacubes() or {}) do
		table.insert(tZonesAtLoad, tCurrZone)
	end

	for key, tCurrZone in pairs(DatacubeLib.GetZonesWithJournals() or {}) do
		table.insert(tZonesAtLoad, tCurrZone)
	end

	for key, tCurrZone in pairs(DatacubeLib.GetZonesWithTales() or {}) do
		table.insert(tZonesAtLoad, tCurrZone)
	end

	for key, strContinent in pairs(karContinents) do
		local wndHeader = Apollo.LoadForm(self.xmlDoc, "DropdownZoneHeader", self.wndColTopDropdownScroll, self)
		wndHeader:FindChild("DropdownZoneHeaderText"):SetText(strContinent)
		wndHeader:SetData(strContinent)
	end

	local tDuplicateList = {}
	local bPickedAZone = false
	for key, tCurrZone in pairs(tZonesAtLoad) do
		if not tDuplicateList[tCurrZone.nZoneId] then
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "DropdownZoneItem", self.wndColTopDropdownScroll, self)
			wndCurr:SetData(String_GetWeaselString(Apollo.GetString("Lore_ContinentZone"), (ktZoneNameToContinent[tCurrZone.strName] or Apollo.GetString("Lore_Other")), tCurrZone.strName))
			wndCurr:FindChild("DropdownZoneBtn"):SetData(tCurrZone)
			wndCurr:FindChild("DropdownZoneBtn"):SetText(tCurrZone.strName)
			self:HelperDrawDropdownZoneProgress(wndCurr, tCurrZone.nZoneId, tCurrZone.strName)

			-- Default the top dropdown to the current zone
			if not self.wndColTopDropdownBtn:GetData() and GameLib.IsInWorldZone(tCurrZone.nZoneId) then
				bPickedAZone = true
				self.wndColTopDropdownBtn:SetData(tCurrZone)
				self.wndColTopDropdownBtn:SetText(tCurrZone.strName)
				self:HelperDrawDropdownZoneProgress(self.wndColTopZoneProgressContainer, tCurrZone.nZoneId, tCurrZone.strName)
			end

			tDuplicateList[tCurrZone.nZoneId] = true
		end
	end

	self.wndColTopDropdownScroll:ArrangeChildrenVert(0, function(a,b) return a:GetData() < b:GetData() end)

	-- Just pick the first one if we didn't match a default zone
	if not bPickedAZone then
		for key, wndCurr in pairs(self.wndColTopDropdownScroll:GetChildren()) do
			if wndCurr:GetName() == "DropdownZoneItem" then
				local tCurrZone = wndCurr:FindChild("DropdownZoneBtn"):GetData()
				self.wndColTopDropdownBtn:SetData(tCurrZone)
				self.wndColTopDropdownBtn:SetText(tCurrZone.strName)
				self:HelperDrawDropdownZoneProgress(self.wndColTopZoneProgressContainer, tCurrZone.nZoneId, tCurrZone.strName)

				break
			end
		end
	end

	self:MainRedrawCollections()
end

function LoreWindow:MainRedrawCollections()
	local tCurrZone = self.wndColTopDropdownBtn:GetData()
	if not tCurrZone or not tCurrZone.nZoneId then
		return
	end

	for idx, strHeader in pairs({Apollo.GetString("Lore_Datacubes"), Apollo.GetString("Lore_Journals"), Apollo.GetString("Lore_Tales")}) do
		local wndHeader = self:FactoryProduce(self.wndColMainScroll, "ColHeader", strHeader)
		wndHeader:FindChild("ColHeaderBtn"):SetData(strHeader)
		if wndHeader:FindChild("ColHeaderBtn"):IsChecked() then
			wndHeader:FindChild("ColHeaderItems"):DestroyChildren()
		else
			local nNumFullyCompleted = self:DrawColHeaderItems(tCurrZone, wndHeader, strHeader)
			local nNumTotal = 0
			if idx == 1 then
				nNumTotal = DatacubeLib.GetTotalDatacubesForZone(tCurrZone.nZoneId) or 0
			elseif idx == 2 then
				nNumTotal = DatacubeLib.GetTotalJournalsForZone(tCurrZone.nZoneId) or 0
			elseif idx == 3 then
				nNumTotal = DatacubeLib.GetTotalTalesForZone(tCurrZone.nZoneId) or 0
			end
			wndHeader:FindChild("ColHeaderBtnText"):SetText(String_GetWeaselString(Apollo.GetString("FloatText_MissionProgress"), strHeader, nNumFullyCompleted, nNumTotal))

			if nNumTotal == 0 then
				wndHeader:Destroy()
			end
		end

		if wndHeader and wndHeader:IsValid() then
			wndHeader:SetAnchorOffsets(0,0,0, wndHeader:FindChild("ColHeaderItems"):ArrangeChildrenVert(0) + self.knWndHeaderDefaultHeight + 3)
		end
	end

	self.wndColMainScroll:ArrangeChildrenVert(0)
	self.wndColMainScroll:Enable(true)
end

function LoreWindow:RedrawFromUI()
	self:MainRedrawCollections()
end

function LoreWindow:DrawColHeaderItems(tCurrZone, wndHeader, strHeader)
	local nNumFullyCompleted = 0

	if strHeader == Apollo.GetString("Lore_Tales") then
		for idx, tListData in pairs(DatacubeLib.GetTalesForZone(tCurrZone.nZoneId) or {}) do
			local nMax = tListData.bIsComplete and 1 or tListData.nNumTotal
			local nComplete = tListData.bIsComplete and 1 or tListData.nNumCompleted
			local wndCurr = self:FactoryProduce(wndHeader:FindChild("ColHeaderItems"), "ColTalesItem", "Tales"..tListData.nDatacubeId)
			wndCurr:FindChild("NewIndicator"):Show(self.tNewEntries[tListData.nDatacubeId])
			wndCurr:FindChild("ColTalesBtn"):SetData(tListData)
			wndCurr:FindChild("ColTalesBtn"):Show(tListData.bIsComplete)
			wndCurr:FindChild("ColListItemText"):SetText(tListData.strTitle)
			wndCurr:FindChild("ColTalesProgBar"):SetMax(nMax)
			wndCurr:FindChild("ColTalesProgBar"):SetProgress(nComplete)
			wndCurr:FindChild("ColTalesProgText"):SetText(tListData.bIsComplete and "" or (String_GetWeaselString(Apollo.GetString("Lore_UnlockedProgress"), nComplete, nMax)))
			wndCurr:FindChild("ColTalesLockedIcon"):Show(not tListData.bIsComplete)
			wndCurr:FindChild("ColTalesCompleteIcon"):Show(tListData.bIsComplete)
			wndCurr:FindChild("ColTalesCompleteIconArt"):SetSprite(tListData.bIsComplete and tListData.strAsset or "")
			nNumFullyCompleted = tListData.bIsComplete and (nNumFullyCompleted + 1) or nNumFullyCompleted
		end
	elseif strHeader == Apollo.GetString("Lore_Datacubes") then
		for idx, tListData in pairs(DatacubeLib.GetDatacubesForZone(tCurrZone.nZoneId) or {}) do
			local wndCurr = self:FactoryProduce(wndHeader:FindChild("ColHeaderItems"), "ColDatacubeItem", "Datacube"..tListData.nDatacubeId)
			wndCurr:FindChild("NewIndicator"):Show(self.tNewEntries[tListData.nDatacubeId])
			if wndCurr:FindChild("ColListItemText"):GetText() ~= tListData.strTitle then -- To avoid constantly setting the costume
				wndCurr:FindChild("ColDatacubeBtn"):SetData(tListData)
				wndCurr:FindChild("ColListItemText"):SetText(tListData.strTitle)
				wndCurr:FindChild("ColDatacubePortrait"):SetCostumeToCreatureId(11098) -- TODO Hardcoded
				wndCurr:FindChild("ColDatacubePortrait"):SetModelSequence(1120)
			end
			nNumFullyCompleted = tListData.bIsComplete and (nNumFullyCompleted + 1) or nNumFullyCompleted
		end
	elseif strHeader == Apollo.GetString("Lore_Journals") then
		for idx, tListData in pairs(DatacubeLib.GetJournalsForZone(tCurrZone.nZoneId) or {}) do
			local nMax = tListData.bIsComplete and 1 or tListData.nNumTotal
			local nComplete = tListData.bIsComplete and 1 or tListData.nNumCompleted
			local wndCurr = self:FactoryProduce(wndHeader:FindChild("ColHeaderItems"), "ColJournalItem", "Journal"..tListData.nDatacubeId)
			wndCurr:FindChild("ColListItemText"):SetText(tListData.strTitle)
			wndCurr:FindChild("ColListItemText"):SetHeightToContentHeight()
			wndCurr:FindChild("ColJournalPortrait"):SetCostumeToCreatureId((idx % 2 == 0) and 30728 or 30737) -- TODO Hardcoded
			wndCurr:FindChild("ColJournalPortrait"):SetModelSequence(150)
			wndCurr:FindChild("ColJournalProgBar"):SetMax(nMax)
			wndCurr:FindChild("ColJournalProgBar"):SetProgress(nComplete)

			wndCurr:FindChild("ColJournalProgText"):SetText(tListData.isComplete and "" or (String_GetWeaselString(Apollo.GetString("Lore_UnlockedProgress"), nComplete, nMax)))
			nNumFullyCompleted = (nMax == nComplete) and (nNumFullyCompleted + 1) or nNumFullyCompleted

			-- Children
			local bShowNewIndicator = false
			for idx3, tCurrArticleData in pairs(DatacubeLib.GetDatacubesForVolume(tListData.nDatacubeId)) do
				if tCurrArticleData.bIsComplete then
					local wndJournalChild = self:FactoryProduce(wndCurr:FindChild("ColJournalChildItems"), "ColJournalChildItem", "JournalArticle"..tCurrArticleData.nDatacubeId)
					wndJournalChild:FindChild("ColJournalChildBtn"):SetData(tCurrArticleData)
					wndJournalChild:FindChild("ColJournalChildBtnText"):SetText(tCurrArticleData.strTitle)
					wndJournalChild:FindChild("ColJournalChildBtnText"):SetHeightToContentHeight()
					local nLeft, nTop, nRight, nBottom = wndJournalChild:GetAnchorOffsets()
					wndJournalChild:SetAnchorOffsets(nLeft, nTop, nRight, wndJournalChild:FindChild("ColJournalChildBtnText"):GetHeight() + 15)
					bShowNewIndicator = self.tNewEntries[tCurrArticleData.nDatacubeId] or bShowNewIndicator
				end
			end
			wndCurr:FindChild("NewIndicator"):Show(bShowNewIndicator)
			wndCurr:SetAnchorOffsets(0,0,0, wndCurr:FindChild("ColJournalChildItems"):ArrangeChildrenVert(0) + self.knWndJournalItemDefaultHeight + wndCurr:FindChild("ColListItemText"):GetHeight())
		end
	end

	if #wndHeader:FindChild("ColHeaderItems"):GetChildren() == 0 then -- GOTCHA: Not the same as nNumFullyCompleted == 0
		Apollo.LoadForm(self.xmlDoc, "EmptyNotification", wndHeader:FindChild("ColHeaderItems"), self)
	end

	return nNumFullyCompleted
end

-----------------------------------------------------------------------------------------------
-- Collections Reader
-----------------------------------------------------------------------------------------------

function LoreWindow:SpawnAndDrawColReader(tArticleData, wndOrigin) -- wndOrigin can be nil
	if not tArticleData then
		return
	end

	if self.tNewEntries[tArticleData.nDatacubeId] then
		self.tNewEntries[tArticleData.nDatacubeId] = nil -- Clear their new indicator right away
		self.wndColMainScroll:DestroyChildren()
		self:MainRedrawCollections()
	end

	if self.wndColDisplay and self.wndColDisplay:IsValid() then
		self:OnDestroyColDisplay()
	end

	local nColDisplayTop = 58
	local nColDisplayLeft = 16
	if not bDockedOption then
		local nLeft, nTop, nRight, nBot = self.wndMain:GetAnchorOffsets()
		nColDisplayTop = nTop + 67
		nColDisplayLeft = nRight - 8
	end

	self.wndColDisplay = Apollo.LoadForm(self.xmlDoc, "MainColArticleDisplay", self.wndMainArticleContainer , self)
	self.wndColDisplay:SetData(wndOrigin)
	self.wndColDisplay:FindChild("PlayPauseButton"):AttachWindow(self.wndColDisplay:FindChild("NowPlayingIcon"))
	self.wndColDisplay:FindChild("PlayPauseButton"):SetData(tArticleData)
	self.wndColDisplay:FindChild("ArticleText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\""..kclrDefault.."\">"..
	tArticleData.strText:gsub("\n", "<T TextColor=\"0\">.</T></P><P Font=\"CRB_InterfaceMedium\" TextColor=\""..kclrDefault.."\">").."</P>")
	self.wndColDisplay:FindChild("ArticleText"):SetHeightToContentHeight()

	local bValidTBFAsset = tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Chronicle and tArticleData.strAsset and string.len(tArticleData.strAsset) > 0
	local strWndNameToUse = tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Datacube and "ArticleDatacubeTitle" or "ArticleNonDatacubeTitle"
	self.wndColDisplay:FindChild(strWndNameToUse):SetText(tArticleData.strTitle)
	self.wndColDisplay:FindChild("TalesLargeCoverArt"):SetSprite(bValidTBFAsset and tArticleData.strAsset or "")
	self.wndColDisplay:FindChild("TalesLargeCover"):Show(bValidTBFAsset)
	self.wndColDisplay:FindChild("PlayPauseButton"):Show(tArticleData.eDatacubeType == DatacubeLib.DatacubeType_Datacube)

	self.wndColDisplay:FindChild("ArticleScroll"):ArrangeChildrenVert(0)
	self.wndColDisplay:FindChild("ArticleScroll"):RecalculateContentExtents()
end

function LoreWindow:OnDestroyColDisplay(wndHandler, wndControl)
	if self.wndColDisplay and self.wndColDisplay:IsValid() then
		local wndOrigin = self.wndColDisplay:GetData()
		if wndOrigin and wndOrigin:IsValid() then
			wndOrigin:SetCheck(false)
		end
		self.wndColDisplay:Destroy()
		self.wndColDisplay = nil

		DatacubeLib.StopDatacubeSound()
		Event_FireGenericEvent("GenericEvent_Collections_StopDatacube") -- To turn off the HUD Alert
	end
end

function LoreWindow:OnPlayPauseCheck(wndHandler, wndControl)
	local tArticleData = wndHandler:GetData()
	DatacubeLib.PlayDatacubeSound(tArticleData.nDatacubeId)
end

function LoreWindow:OnPlayPauseUncheck(wndHandler, wndControl)
	local tArticleData = wndHandler:GetData()
	self.nEndingArticleId = tArticleData.nDatacubeId

	DatacubeLib.StopDatacubeSound()
	Event_FireGenericEvent("GenericEvent_Collections_StopDatacube") -- To turn off the HUD Alert

	self.wndColDisplay:FindChild("PlayPauseButton"):Enable(false)
	self.timerDatacubeStopping:Start()
end

function LoreWindow:OnDatacubeStopped()
	if self.wndColDisplay and self.wndColDisplay:IsValid() then
		self.wndColDisplay:FindChild("PlayPauseButton"):SetCheck(false)
	end
end

function LoreWindow:OnDatacubeTimer()
	if self.wndColDisplay and self.wndColDisplay:IsValid() then
		self.wndColDisplay:FindChild("PlayPauseButton"):Enable(true)
	end
end

-----------------------------------------------------------------------------------------------
-- Interaction
-----------------------------------------------------------------------------------------------

function LoreWindow:OnDropdownZoneBtn(wndHandler, wndControl) -- wndHandler is "DropdownZoneBtn" and its data is tCurrZone
	local tCurrZone = wndHandler:GetData()
	self.wndColTopDropdownBtn:SetCheck(false)
	self.wndColTopDropdownBtn:SetData(tCurrZone)
	self.wndColTopDropdownBtn:SetText(tCurrZone.strName)
	self:HelperDrawDropdownZoneProgress(self.wndColTopZoneProgressContainer, tCurrZone.nZoneId, tCurrZone.strName)
	self.wndColMainScroll:SetVScrollPos(0)
	self.wndColMainScroll:DestroyChildren()
	self:MainRedrawCollections()
	self:OnDestroyColDisplay()
end

function LoreWindow:OnColTopDropdownToggle(wndHandler, wndControl) -- ColTopDropdownBtn Zone Picker
	self.wndColMainScroll:Enable(not wndHandler:IsChecked())
end

function LoreWindow:OnColTopDropdownClosed(wndHandler, wndControl) -- ColTopDropdownBtn Zone Picker Window
	self.wndColMainScroll:Enable(true)
end

function LoreWindow:OnColHeaderToggle(wndHandler, wndControl) -- E.G. "Datacubes (1/6)"
	if wndHandler:IsChecked() then
		wndHandler:GetParent():FindChild("ColHeaderItems"):DestroyChildren()
		self:OnDestroyColDisplay()
	end
	self:MainRedrawCollections()
end

function LoreWindow:OnColBtnToSpawnReader(wndHandler, wndControl) -- ColDatacubeBtn, ColTalesBtn, ColJournalChildBtn
	local wndNewIndicator = wndHandler:GetParent():FindChild("NewIndicator")
	if wndNewIndicator then
		wndNewIndicator:Show(false)
	end
	self:SpawnAndDrawColReader(wndHandler:GetData(), wndHandler)
end

function LoreWindow:OnColBtnToDespawnReader(wndHandler, wndControl) -- ColDatacubeBtn, ColTalesBtn, ColJournalChildBtn, MainColArticleDisplay
	self:OnDestroyColDisplay()
end

function LoreWindow:OnMainNavGACheck(wndHandler, wndControl)
	self:OnDestroyColDisplay()
end

function LoreWindow:OnMainNavColCheck(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_CloseGAReader")
end

function LoreWindow:OnCompactLore()
	bDockedOption = not bDockedOption
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------

function LoreWindow:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor ~= GameLib.CodeEnumTutorialAnchor.GalacticArchive or not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function LoreWindow:HelperDrawDropdownZoneProgress(wndCurr, idCurrZone, strCurrZoneName) -- wndCurr is "DropdownZoneItem" -- TODO: Refactor if possible
	local nTotalDatacubes = DatacubeLib.GetTotalDatacubesForZone(idCurrZone) or 0
	local nTotalJournals = DatacubeLib.GetTotalJournalsForZone(idCurrZone) or 0
	local nTotalTales = DatacubeLib.GetTotalTalesForZone(idCurrZone) or 0
	local nTotalSum = nTotalDatacubes + nTotalTales + nTotalJournals

	local nCurrent = 0
	for key, tCurrTable in pairs({ DatacubeLib.GetDatacubesForZone(idCurrZone), DatacubeLib.GetTalesForZone(idCurrZone), DatacubeLib.GetJournalsForZone(idCurrZone) }) do
		for key2, tCurrEntry in pairs(tCurrTable) do
			if tCurrEntry.bIsComplete then
				nCurrent = nCurrent + 1
			end
		end
	end

	if wndCurr:FindChild("ZoneProgressProgText") then
		wndCurr:FindChild("ZoneProgressProgText"):SetText(String_GetWeaselString(Apollo.GetString("Lore_TotalProgress"), nCurrent, nTotalSum))
	end

	wndCurr:FindChild("ZoneProgressProgBar"):SetMax(nTotalSum)
	wndCurr:FindChild("ZoneProgressProgBar"):SetProgress(nCurrent)
	wndCurr:FindChild("ZoneProgressProgBar"):EnableGlow(nCurrent == nTotalSum)
	wndCurr:SetTooltip(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</P>", String_GetWeaselString(Apollo.GetString("Lore_ZoneProgress"), strCurrZoneName, nCurrent, nTotalSum)))
end

function LoreWindow:FactoryProduce(wndParent, strFormName, tObject)
	local wndNew = wndParent:FindChildByUserData(tObject)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndNew:SetData(tObject)
	end
	return wndNew
end

local LoreWindowInst = LoreWindow:new()
LoreWindowInst:Init()
