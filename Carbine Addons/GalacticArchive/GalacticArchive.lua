-----------------------------------------------------------------------------------------------
-- Client Lua Script for GalacticArchive
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GalacticArchiveArticle"
require "GalacticArchiveEntry"

local GalacticArchive = {}

local kclrDefault = "ff62aec1"

function GalacticArchive:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function GalacticArchive:Init()
    Apollo.RegisterAddon(self)
end

function GalacticArchive:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GalacticArchive.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function GalacticArchive:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("ToggleGalacticArchiveWindow", 	"OnToggleGalacticArchiveWindow", self)
	Apollo.RegisterEventHandler("GenericEvent_CloseGAReader", 	"OnBack", self)
end

function GalacticArchive:Initialize(wndParent, wndMostTopLevel)
	Apollo.RegisterEventHandler("GalacticArchiveArticleAdded", 	"OnGalacticArchiveArticleAdded", self)
	Apollo.RegisterEventHandler("GalacticArchiveEntryAdded", 	"OnGalacticArchiveEntryAdded", self)
	Apollo.RegisterEventHandler("GalacticArchiveRefresh", 		"OnGalacticArchiveRefresh", self)

	self.wndArchiveIndexForm = 	Apollo.LoadForm(self.xmlDoc, "ArchiveIndex", wndParent, self)
	self.wndArticleDisplay = 	Apollo.LoadForm(self.xmlDoc, "ArticleDisplay", nil, self)
	self.wndHeaderContainer = 	self.wndArchiveIndexForm:FindChild("HeaderContainer")
	self.wndFilterShowAll = 	self.wndArchiveIndexForm:FindChild("TopRowShowAllFilter")
	self.wndFilterUpdated = 	self.wndArchiveIndexForm:FindChild("TopRowUpdatedFilter")

	self.tArticles = {}
	self.artDisplayed = nil
	self.wndMostTopLevel = wndMostTopLevel
	self.wndArticleDisplay:Show(false, true)
	--self.wndArchiveIndexForm:SetSizingMinimum(362, 300)
	--self.wndArchiveIndexForm:SetSizingMaximum(362, 1200)

	-- My variables
	self.tSkipHeaders = {}
	self.tListOfLetters = {}
	self.tWndTopFilters = {}
	self.strCurrTypeFilter = ""

	self.nEntryLeft, self.nEntryTop, self.nEntryRight, self.nEntryBottom = self.wndArticleDisplay:FindChild("ArticleScroll"):FindChild("EntriesContainer"):GetAnchorOffsets()

	-- Set up top filters
	self.wndFilterShowAll:SetData(Apollo.GetString("Archive_ShowAllArticles"))
	self.wndFilterUpdated:SetData(Apollo.GetString("Archive_Updated"))

	-- Default is Updated if possible, else Show All
	if self:HelperIsThereAnyNew() then
		self.wndFilterUpdated:SetCheck(true)
		self.strCurrTypeFilter = Apollo.GetString("Archive_Updated")
	else
		self.wndFilterShowAll:SetCheck(true)
		self.strCurrTypeFilter = Apollo.GetString("Archive_ShowAllArticles")
	end

	-- Set up rest of filters
	for idx, strCurrCategory in ipairs(GalacticArchiveArticle.GetAllCategories()) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "FilterTypeItem", self.wndArchiveIndexForm:FindChild("TypeFilterContainer"), self)
		wndCurr:FindChild("FilterIcon"):SetTooltip(string.format(
			"<P Font=\"CRB_InterfaceSmall\" TextColor=\"ff9d9d9d\">%s<P TextColor=\"ffffffff\">%s</P></P>", Apollo.GetString("Archive_ShowArticlesOnTopic"), strCurrCategory))
		self:HelperDrawTypeIcon(wndCurr:FindChild("FilterIcon"), nil, strCurrCategory)
		wndCurr:FindChild("FilterTypeBtn"):SetData(strCurrCategory)
		table.insert(self.tWndTopFilters, wndCurr)
	end
	self.wndArchiveIndexForm:FindChild("TypeFilterContainer"):ArrangeChildrenTiles()
end

function GalacticArchive:OnToggleGalacticArchiveWindow(wndParent, wndMostTopLevel)
	if not self.wndArchiveIndexForm or not self.wndArchiveIndexForm:IsValid() then
		self:Initialize(wndParent, wndMostTopLevel)
	end

	if self.strCurrTypeFilter ~= Apollo.GetString("Archive_Updated") and self:HelperIsThereAnyNew() then
		for idx, wndCurr in ipairs(self.tWndTopFilters) do
			if wndCurr then
				wndCurr:FindChild("FilterTypeBtn"):SetCheck(false)
			end
		end

		self.strCurrTypeFilter = Apollo.GetString("Archive_Updated")
		self.wndFilterUpdated:SetCheck(true)
		self.wndFilterShowAll:SetCheck(false)
	end

	self:PopulateArchiveIndex()
	self.wndArchiveIndexForm:Show(not self.wndArchiveIndexForm:IsShown())
end

function GalacticArchive:OnFilterShowAllSelect(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then
		self.strCurrTypeFilter = wndHandler:GetData()
	end
	self:PopulateArchiveIndex()
end

function GalacticArchive:OnFilterTypeSelect(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then
		self.strCurrTypeFilter = wndHandler:GetData()
	end

	wndHandler:SetCheck(true)

	self.wndFilterShowAll:SetCheck(false)
	self:PopulateArchiveIndex()


end

function GalacticArchive:OnFilterTypeUnselect(wndHandler, wndControl)
	-- All filters have this, including Recently Updated, except "Show All" (which can't deselect)
	for idx, wndCurr in ipairs(self.tWndTopFilters) do
		if wndCurr then
			wndCurr:FindChild("FilterTypeBtn"):SetCheck(false)
		end
	end

	wndHandler:SetCheck(false)

	self.strCurrTypeFilter = Apollo.GetString("Archive_ShowAll")
	self.wndFilterShowAll:SetCheck(true)
	self:PopulateArchiveIndex()
end

function GalacticArchive:OnNameFilterChanged()
	self:PopulateArchiveIndex()
end

function GalacticArchive:OnHeaderBtnItemClick(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then
		local strLetter = wndHandler:GetData():lower()
		if self.tSkipHeaders[strLetter] == nil or self.tSkipHeaders[strLetter] == false then
			self.tSkipHeaders[strLetter] = true
		else
			self.tSkipHeaders[strLetter] = false
		end

		local nScrollPos = self.wndHeaderContainer:GetVScrollPos()
		self:PopulateArchiveIndex()
		self.wndHeaderContainer:SetVScrollPos(nScrollPos)
	end

	return true -- stop propogation
end

-----------------------------------------------------------------------------------------------
-- ArchiveIndex Functions
-----------------------------------------------------------------------------------------------

-- Static
function GalacticArchive:BuildArchiveList()
	-- If nil, we will skip this filter later on
	local strNameChoice = self.wndArchiveIndexForm:FindChild("SearchFilter"):GetText()
    if strNameChoice == "" then
		strNameChoice = nil
	end

	local strCatChoice = self.strCurrTypeFilter
	if strCatChoice == "" then
		strCatChoice = nil
	end

    self.tArticles = GalacticArchiveArticle.GetArticles()
	local tResult = {}
    for idx, artCurr in ipairs(self.tArticles) do
		local strTitle = self:GetTitleMinusThe(artCurr)
		local bPass = true

		if strCatChoice and strCatChoice ~= Apollo.GetString("Archive_ShowAll") and strCatChoice ~= Apollo.GetString("Archive_Updated") and not artCurr:GetCategories()[strCatChoice] then
			bPass = false
		elseif strCatChoice and strCatChoice == Apollo.GetString("Archive_Updated") and not self:HelperIsNew(artCurr) then
			bPass = false
		end

		-- Find the first character of a word or an exact match from the start
		if bPass and strNameChoice then
			local strNameChoiceLower = strNameChoice:lower()
			if not (strTitle:lower():find(" "..strNameChoiceLower) or string.sub(strTitle, 0, string.len(strNameChoice)):lower() == strNameChoiceLower) then
				bPass = false
			end
		end

		if bPass then
			table.insert(tResult, artCurr)
		end
    end

	-- Sort alphabetically
	table.sort(tResult, function (a,b) return (self:GetTitleMinusThe(a) < self:GetTitleMinusThe(b)) end)
	return tResult
end

function GalacticArchive:OnHeaderBtnMouseEnter(wndHandler, wndControl)
	wndHandler:FindChild("HeaderBtnText"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
end

function GalacticArchive:OnHeaderBtnMouseExit(wndHandler, wndControl)
	wndHandler:FindChild("HeaderBtnText"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
end

function GalacticArchive:OnEmptyLabelBtn(wndHandler, wndControl)
	-- Simulate clicking "Show All" and clear search
	self.wndArchiveIndexForm:FindChild("SearchFilter"):SetText("")
	self.wndArchiveIndexForm:FindChild("SearchFilter"):Enable(false)
	self.wndArchiveIndexForm:FindChild("SearchFilter"):Enable(true) -- HACK: Deselect the search box
	for key, wndCurr in pairs(self.wndArchiveIndexForm:FindChild("TypeFilterContainer"):GetChildren()) do
		wndCurr:FindChild("FilterTypeBtn"):SetCheck(false)
	end
	self.wndFilterUpdated:SetCheck(false)
	self.wndFilterShowAll:SetCheck(true)
	self.strCurrTypeFilter = Apollo.GetString("Archive_ShowAll")
	self:PopulateArchiveIndex()
end

function GalacticArchive:PopulateArchiveIndex()
	if not self.wndArchiveIndexForm or not self.wndArchiveIndexForm:IsValid() then
		return
	end

	self.wndHeaderContainer:DestroyChildren()
	self.tListOfLetters = {}

	local tArticlesToAdd = self:BuildArchiveList()
	for idx, artCurr in ipairs(tArticlesToAdd) do
		self:BuildAHeader(artCurr)
	end

	-- Count number of new articles
	local nNumOfNewArticles = 0
	for idx, artCurr in ipairs(GalacticArchiveArticle.GetArticles()) do --for nIdx, article in ipairs(tArticlesToAdd) do
		if self:HelperIsNew(artCurr) then
			nNumOfNewArticles = nNumOfNewArticles + 1
		end
	end

	-- Empty Label and etc. formatting
	self.wndArchiveIndexForm:FindChild("EmptyLabel"):Show(#self.wndHeaderContainer:GetChildren() == 0)
	self.wndArchiveIndexForm:FindChild("EmptyLabel"):SetText(String_GetWeaselString(Apollo.GetString("Archive_NoEntriesFound"), self.strCurrTypeFilter))
	self.wndArchiveIndexForm:FindChild("BGTitleText"):SetText(String_GetWeaselString(Apollo.GetString("Archive_TitleWithFilter"), self.strCurrTypeFilter))

	if nNumOfNewArticles == 0 then

		self.wndFilterUpdated:SetText(Apollo.GetString("Archive_UpdatedArticles"))
	else
		self.wndFilterUpdated:SetText(String_GetWeaselString(Apollo.GetString("Archive_UpdatedArticlesNumber"), nNumOfNewArticles))
	end

	self.wndHeaderContainer:ArrangeChildrenVert()
end

function GalacticArchive:BuildAHeader(artBuilding)
	local strLetter = string.sub(self:GetTitleMinusThe(artBuilding), 0, 1):lower()
	if strLetter == nil or strLetter == "" then
		strLetter = Apollo.GetString("Archive_Unspecified")
	end

	-- Draw the header (try to find it via FindChild and our List before making a new one)
	-- Try to find it first
	local wndHeader = self.wndHeaderContainer:FindChildByUserData(strLetter:lower())
	for strIdxLetter, wndCurr in pairs(self.tListOfLetters) do	-- GOTCHA: This is necessary incase FindChild's target doesn't update quick enough
		if strIdxLetter:lower() == strLetter and wndCurr ~= nil then
			wndHeader = wndCurr
		end
	end

	if wndHeader == nil then
		wndHeader = Apollo.LoadForm(self.xmlDoc, "HeaderItem", self.wndHeaderContainer, self)
	end

	wndHeader:SetData(strLetter)
	wndHeader:FindChild("HeaderBtn"):SetData(strLetter) -- Used by OnHeaderBtnItemClick
	wndHeader:FindChild("HeaderBtnText"):SetText(strLetter:upper()) -- Add children in a separate method since we need FindChild detection
	self.tListOfLetters[strLetter] = wndHeader

	-- Load children
	if self.tSkipHeaders[strLetter] == nil or self.tSkipHeaders[strLetter] == false then
		wndHeader:FindChild("HeaderBtn"):SetCheck(true)
		self:AddArticleToIndex(artBuilding, wndHeader:FindChild("HeaderItemContainer"))

		local nLeft, nTop, nRight, nBottom = wndHeader:GetAnchorOffsets()
		wndHeader:SetAnchorOffsets(nLeft, nTop, nRight, nTop + wndHeader:FindChild("HeaderItemContainer"):ArrangeChildrenVert(0) + 63)
	else
		wndHeader:FindChild("HeaderBtn"):SetCheck(false)
		--local nLeft, nTop, nRight, nBottom = wndHeader:GetAnchorOffsets()
		--wndHeader:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 44)
	end
end

-----------------------------------------------------------------------------------------------
-- Add Article
-----------------------------------------------------------------------------------------------

function GalacticArchive:AddArticleToIndex(artData, wndParent)
	local wndArticle = wndParent:FindChildByUserData(artData)
	if wndArticle then
		return
	end

	wndArticle = Apollo.LoadForm(self.xmlDoc, "ArchiveIndexItem", wndParent, self)

	local nLockCount = 0
	local nEntryCount = 1 -- Base article will artificially count
	for idx, entCurr in ipairs(artData:GetEntries()) do
		if entCurr:IsUnlocked() then
			nEntryCount = nEntryCount + 1
		else
			nLockCount = nLockCount + 1
		end
	end
	local nMaxCount = nEntryCount + nLockCount
	local bHasCostume = artData:GetHeaderCreature() and artData:GetHeaderCreature() ~= 0

	if bHasCostume then
		wndArticle:FindChild("ArticlePortrait"):SetCostumeToCreatureId(artData:GetHeaderCreature())
	elseif string.len(artData:GetHeaderIcon()) > 0 then
		wndArticle:FindChild("ArticleIcon"):SetSprite(artData:GetHeaderIcon())
	else
		wndArticle:FindChild("ArticleIcon"):SetSprite("Icon_Mission_Explorer_PowerMap")
	end
	wndArticle:FindChild("ArticleIcon"):Show(not bHasCostume)
	wndArticle:FindChild("ArticlePortrait"):Show(bHasCostume)

	wndArticle:SetData(artData)
	wndArticle:FindChild("ArticleProgress"):SetMax(nMaxCount)
	wndArticle:FindChild("ArticleProgress"):SetProgress(nEntryCount)
	wndArticle:FindChild("ArticleProgressText"):SetText(nEntryCount == nMaxCount and "" or String_GetWeaselString(Apollo.GetString("Archive_UnlockedCount"), nEntryCount, nMaxCount))
	wndArticle:FindChild("NewIndicator"):Show(self:HelperIsNew(artData))
	wndArticle:FindChild("ArchiveIndexItemTitle"):SetText(artData:GetTitle())
	self:HelperDrawTypeIcon(wndArticle:FindChild("ArticleTypeIcon"), artData)
end

function GalacticArchive:HelperIsNew(artCurr)
	local bIsNew = false

	if artCurr and artCurr:IsViewed() then	-- Incase it is viewed, check entries too
		for idx, entCurr in ipairs(artCurr:GetEntries()) do
			if entCurr:IsUnlocked() and not entCurr:IsViewed() then
				bIsNew = true
			end
		end
	elseif artCurr then
		bIsNew = true
	end

	return bIsNew
end

function GalacticArchive:HelperIsThereAnyNew()
    for idx, artCurr in ipairs(GalacticArchiveArticle.GetArticles()) do
		if self:HelperIsNew(artCurr) then
			return true
		end
	end
	return false
end

function GalacticArchive:HelperDrawTypeIcon(wndArg, artCheck, strCategory)
	-- TODO This is all hard coded temporary
	local strSprite = ""
	local artCheckCategories = artCheck and artCheck:GetCategories() or nil
	if (strCategory and strCategory == "Lore") or (artCheck and artCheckCategories["Lore"]) then
		strSprite = "CRB_GuildSprites:sprGuild_Flute"
	elseif (strCategory and strCategory == "Tech") or (artCheck and artCheckCategories["Tech"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Syringe"
	elseif (strCategory and strCategory == "Plants") or (artCheck and artCheckCategories["Plants"]) then
		strSprite = "CRB_GuildSprites:sprGuild_Leaf"
	elseif (strCategory and strCategory == "Allies") or (artCheck and artCheckCategories["Allies"]) then
		strSprite = "CRB_GuildSprites:sprGuild_Lopp"
	elseif (strCategory and strCategory == "Enemies") or (artCheck and artCheckCategories["Enemies"]) then
		strSprite = "CRB_GuildSprites:sprGuild_Skull"
	elseif (strCategory and strCategory == "Minerals") or (artCheck and artCheckCategories["Minerals"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Pearl"
	elseif (strCategory and strCategory == "Factions") or (artCheck and artCheckCategories["Factions"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Candles"
	elseif (strCategory and strCategory == "Creatures") or (artCheck and artCheckCategories["Creatures"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Hand"
	elseif (strCategory and strCategory == "Locations") or (artCheck and artCheckCategories["Locations"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Blueprint"
	elseif (strCategory and strCategory == "Sentient Species") or (artCheck and artCheckCategories["Sentient Species"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Key"
	elseif (strCategory and strCategory == "The Nexus Project") or (artCheck and artCheckCategories["The Nexus Project"]) then
		strSprite = "CRB_GuildSprites:sprGuild_Potion"
	elseif (strCategory and strCategory == "Notable Individuals") or (artCheck and artCheckCategories["Notable Individuals"]) then
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Blueprint" -- Doubled with Location
	else
		strSprite = "ClientSprites:Icon_Guild_UI_Guild_Blueprint"
		wndArg:SetTooltip(Apollo.GetString("Archive_ArticleNotClassified"))
	end

	wndArg:SetSprite(strSprite)
end

-----------------------------------------------------------------------------------------------
-- Transition Between The Two Classes Functions
-----------------------------------------------------------------------------------------------

-- when a archive item is selected
function GalacticArchive:OnIndexItemUncheck(wndHandler, wndControl) -- ArchiveIndexItem
	if not wndHandler:IsChecked() then
		self:OnBack()
	end
end

function GalacticArchive:OnIndexItemCheck(wndHandler, wndControl) -- ArchiveIndexItem
	if wndHandler and wndHandler:FindChild("NewIndicator") then
		wndHandler:FindChild("NewIndicator"):Show(false)
	end
	self:DisplayArticle(wndHandler:GetData())
end

function GalacticArchive:OnGalacticArchiveArticleAdded(artNew)
	if not self.wndArchiveIndexForm:IsVisible() then
		return
	end

	if not self.artDisplayed then
		self:PopulateArchiveIndex()
		return
	elseif self.artDisplayed and self.artDisplayed == artNew then
		self:DisplayArticle(artNew)
		return
	end

	-- Else we don't have one displayed, so search for it
	for idx, artLinked in ipairs(self.artDisplayed:GetLinks(GalacticArchiveArticle.LinkQueryType_All)) do
		if artNew == artLinked then
			self:DisplayArticle(self.artDisplayed)
			return
		end
	end
end

function GalacticArchive:OnGalacticArchiveEntryAdded(artParent, entNew)
	if not self.wndArchiveIndexForm:IsVisible() then
		return
	end

	if not self.artDisplayed then
		self:PopulateArchiveIndex()
	elseif self.artDisplayed and self.artDisplayed == artParent then
		self:DisplayArticle(artParent)
	end
end

function GalacticArchive:OnGalacticArchiveRefresh()
	if not self.wndArchiveIndexForm:IsVisible() then
		return
	end

	if self.artDisplayed then
		self:OnBack()
	else
		self:PopulateArchiveIndex()
	end
end

-----------------------------------------------------------------------------------------------
-- GalacticArchiveForm Functions
-----------------------------------------------------------------------------------------------

function GalacticArchive:DisplayArticle(artDisplay)
	-- TODO Tons of hard coded formatting and strings for translation
    if not artDisplay then
		return
	end

	self.artDisplayed = artDisplay
	artDisplay:SetViewed()

	self.wndArchiveIndexForm:FindChild("SearchFilter"):Enable(false)
	self.wndArchiveIndexForm:FindChild("SearchFilter"):Enable(true) -- HACK: Deselect the search box

	-- Top
	local wndArticle = self.wndArticleDisplay
	local strCategories = ""
	for strCurr, value in pairs(artDisplay:GetCategories()) do
		if strCategories == "" then
			strCategories = strCurr
		else
			strCategories = String_GetWeaselString(Apollo.GetString("Archive_TextList"), strCategories, strCurr)
		end
	end

	if artDisplay:GetWorldZone() and artDisplay:GetWorldZone() ~= "" then
		strCategories = String_GetWeaselString(Apollo.GetString("Archive_ZoneCategories"), artDisplay:GetWorldZone(), strCategories)
	end

	local bHasCostume = artDisplay:GetHeaderCreature() and artDisplay:GetHeaderCreature() ~= 0
	if bHasCostume then
		wndArticle:FindChild("ArticleDisplayCostumeWindow"):SetCostumeToCreatureId(artDisplay:GetHeaderCreature())
	elseif string.len(artDisplay:GetHeaderIcon()) > 0 then
		wndArticle:FindChild("ArticleDisplayIcon"):SetSprite(artDisplay:GetHeaderIcon())
	else
		wndArticle:FindChild("ArticleDisplayIcon"):SetSprite("Icon_Mission_Explorer_PowerMap")
	end
	wndArticle:FindChild("ArticleDisplayIcon"):Show(not bHasCostume)
	wndArticle:FindChild("ArticleDisplayCostumeWindow"):Show(bHasCostume)
	-- End Top

	wndArticle:FindChild("ArticleScientistOnlyIcon"):Show(false)
	wndArticle:FindChild("ArticleTitle"):SetText(artDisplay:GetTitle())
	wndArticle:FindChild("ArticleSubtitle"):SetText(strCategories)
	wndArticle:FindChild("ArticleText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\""..kclrDefault.."\">"..self:ReplaceLineBreaks(artDisplay:GetText()).."</P>")
	wndArticle:FindChild("ArticleText"):SetHeightToContentHeight()

	local nLockCount = 0
	local nEntryCount = 0
	local nAdditionalHeight = 0
	wndArticle:FindChild("EntriesContainerList"):DestroyChildren()
	wndArticle:FindChild("EntriesContainer"):SetAnchorOffsets(0, 0, 0, 0)

	for idx, entCurr in ipairs(artDisplay:GetEntries()) do
		local tResults = self:DrawEntry(entCurr, wndArticle)
		nLockCount = nLockCount + tResults[1]
		nEntryCount = nEntryCount + tResults[2]
		nAdditionalHeight = nAdditionalHeight + tResults[3]
	end

	-- Middle
	wndArticle:FindChild("TitleContainer"):Show(artDisplay:GetCompletionTitle())
	wndArticle:FindChild("TitleProgressBar"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Progress"), nEntryCount, nEntryCount + nLockCount))
	wndArticle:FindChild("TitleProgressBar"):SetProgress(nEntryCount / (nEntryCount + nLockCount))
	wndArticle:FindChild("TitleProgressBar"):EnableGlow(nEntryCount > 0)

	local tCompletionTitle = artDisplay:GetCompletionTitle()
	local bFemale = GameLib.GetPlayerUnit() and GameLib.GetPlayerUnit():GetGender() and GameLib.GetPlayerUnit():GetGender() == Unit.CodeEnumGender.Female
	if tCompletionTitle and bFemale then
		wndArticle:FindChild("TitleEarned"):SetText(tCompletionTitle:GetFemaleTitle())
	elseif artDisplay:GetCompletionTitle() then
		wndArticle:FindChild("TitleEarned"):SetText(tCompletionTitle:GetMaleTitle())
	end

	if artDisplay:GetCompletionTitle() and artDisplay:GetCompletionTitle():GetSpell() then
		wndArticle:FindChild("TitleSpell"):SetSprite(artDisplay:GetCompletionTitle():GetSpell():GetIcon())
		wndArticle:FindChild("TitleSpell"):SetTooltip(artDisplay:GetCompletionTitle():GetSpell():GetName())
	else
		wndArticle:FindChild("TitleSpell"):SetSprite("CRB_GuildSprites:sprGuild_Glave")
		wndArticle:FindChild("TitleSpell"):SetTooltip(Apollo.GetString("Archive_UncoverArticle"))
	end
	-- End Middle

	wndArticle:FindChild("EntriesContainer"):SetAnchorOffsets(self.nEntryLeft, self.nEntryTop, self.nEntryRight, self.nEntryBottom + nAdditionalHeight)
	wndArticle:FindChild("EntriesContainerList"):ArrangeChildrenVert(0)

	wndArticle:FindChild("ArticleScroll"):SetVScrollPos(0)
	wndArticle:FindChild("ArticleScroll"):RecalculateContentExtents()
	wndArticle:FindChild("ArticleScroll"):ArrangeChildrenVert(0)

	self.wndArchiveIndexForm:Show(true)
	self.wndArticleDisplay:Show(true) -- wndArticle
	self.wndArticleDisplay:ToFront() -- wndArticle
end

function GalacticArchive:DrawEntry(entDraw, wndArticle)
	local wndEntry = Apollo.LoadForm(self.xmlDoc, "EntryDisplayItem", wndArticle:FindChild("EntriesContainerList"), self)
	local nLockCount = 0
	local nEntryCount = 0

	local strHeaderStyle = entDraw:GetHeaderStyle()
	if strHeaderStyle == GalacticArchiveEntry.ArchiveEntryHeaderEnum_TextWithPortrait then
		wndEntry:FindChild("EntryCostumeWindow"):SetCostumeToCreatureId(entDraw:GetHeaderCreature())
	elseif strHeaderStyle == GalacticArchiveEntry.ArchiveEntryHeaderEnum_TextWithIcon then
		wndEntry:FindChild("EntryIcon"):SetSprite(entDraw:GetHeaderIcon())
	elseif not entDraw:IsUnlocked() then
		wndEntry:FindChild("EntryIcon"):SetSprite("Icon_Windows_UI_CRB_Lock_Holo")
	else
		wndEntry:FindChild("EntryIcon"):SetSprite("Icon_Mission_Scientist_ReverseEngineering")
	end

	-- Costume Window only when TextWithPortrait, else Entry Icon
	wndEntry:FindChild("EntryIcon"):Show(strHeaderStyle ~= GalacticArchiveEntry.ArchiveEntryHeaderEnum_TextWithPortrait)
	wndEntry:FindChild("EntryCostumeWindow"):Show(strHeaderStyle == GalacticArchiveEntry.ArchiveEntryHeaderEnum_TextWithPortrait)

	if entDraw:IsUnlocked() then
		nEntryCount = nEntryCount + 1
		wndEntry:FindChild("EntryTitle"):SetText(entDraw:GetTitle())
		wndEntry:SetTooltip("")
	else
		nLockCount = nLockCount + 1
		wndEntry:FindChild("EntryTitle"):SetText(Apollo.GetString("Archive_Locked"))
		wndEntry:SetTooltip(string.format("<T Font=\"CRB_InterfaceSmall_O\">%s</T>", Apollo.GetString("Archive_ExploreWorld")))
	end

	-- Text
	local strEntryText = ""
	if string.len(entDraw:GetText()) > 0 then
		strEntryText = entDraw:GetText()
	end
	if string.len(entDraw:GetScientistText()) > 0 then
		wndEntry:FindChild("EntryScientistOnlyIcon"):Show(true)
		wndArticle:FindChild("ArticleScientistOnlyIcon"):Show(true)
		strEntryText = strEntryText .."</P>\\n<P Font=\"CRB_InterfaceMedium\" TextColor=\"ffffb97f\">"..entDraw:GetScientistText().."</P>"
	end
	wndEntry:FindChild("EntryText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\""..kclrDefault.."\">"..self:ReplaceLineBreaks(strEntryText).."</P>")
	wndEntry:FindChild("EntryText"):SetHeightToContentHeight()

	local nTextLeft, nTextTop, nTextRight, nTextBottom = wndEntry:FindChild("EntryText"):GetAnchorOffsets()
	local nLeft, nTop, nRight, nBottom = wndEntry:GetAnchorOffsets()
	wndEntry:SetAnchorOffsets(nLeft, nTop, nRight, nTextBottom + 8) -- The +8 is extra padding below the text and frame
	return { nLockCount, nEntryCount, nTextBottom + 8 }
end

function GalacticArchive:OnBack()
	if not self.artDisplayed then
		return
	end

	local nScrollPos = self.wndHeaderContainer:GetVScrollPos()
	self:PopulateArchiveIndex()
	self.wndHeaderContainer:SetVScrollPos(nScrollPos)

	self.artDisplayed = nil

	self.wndArchiveIndexForm:Show(true)
	self.wndArticleDisplay:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function GalacticArchive:ReplaceLineBreaks(strArg)
	return strArg:gsub("\\n", "<T TextColor=\"0\">.</T></P><P Font=\"CRB_InterfaceMedium\" TextColor=\""..kclrDefault.."\">")
end

function GalacticArchive:GetTitleMinusThe(artTitled)
	if string.sub(artTitled:GetTitle(), 0, 4) == Apollo.GetString("Archive_DefiniteArticle") then
		return string.sub(artTitled:GetTitle(), 5)
	else
		return artTitled:GetTitle()
	end
end

local GalacticArchiveInst = GalacticArchive:new()
GalacticArchiveInst:Init()
