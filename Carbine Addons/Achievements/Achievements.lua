-----------------------------------------------------------------------------------------------
-- Client Lua Script for Achievements
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "Window"
require "Achievement"
require "AchievementsLib"

local Achievements = {}

local kaRomanNumeralNumbers = { 1, 5, 10, 50, 100, 500, 1000 }
local kaRomanNumeralChars = { "I", "V", "X", "L", "C", "D", "M" }
local ktRomanNumeralMap =
{
    I = 1,
    V = 5,
    X = 10,
    L = 50,
    C = 100,
    D = 500,
    M = 1000,
}


local ktAchievementIconsText =
{
	[1	]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[2	]		= "IconSprites:Icon_Achievement_Achievement_GenericAchievement",
	[3	]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[4	]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[7	]		= "IconSprites:Icon_Achievement_Achievement_PvP",
	[8	]		= "IconSprites:Icon_Achievement_Achievement_MetaAchievement",
	[9	]		= "IconSprites:Icon_Achievement_Achievement_Path_Explorer",
	[10	]		= "IconSprites:Icon_Achievement_Achievement_Datacube",
	[11	]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[12	]		= "IconSprites:Icon_Achievement_Achievement_GenericAchievement",
	[65	]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[161]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[162]		= "IconSprites:Icon_Achievement_Achievement_Shiphand",
	[164]		= "IconSprites:Icon_Achievement_Achievement_Raid",
	[175]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[281]		= "IconSprites:Icon_Achievement_Achievement_Social",
	[284]		= "IconSprites:Icon_Achievement_Achievement_ServerWide_General",
	[290]		= "IconSprites:Icon_Achievement_Achievement_GenericAchievement",
	[191]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[192]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[193]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[194]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[195]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[196]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[197]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[198]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[199]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[200]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[201]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[202]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[203]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[204]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[205]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[206]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[207]		= "IconSprites:Icon_Achievement_Achievement_Exploration",
	[176]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[177]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[178]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[179]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[180]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[181]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[182]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[183]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[184]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[185]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[186]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[187]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[188]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[189]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[190]		= "IconSprites:Icon_Achievement_Achievement_Quest",
	[208]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[209]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[210]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[211]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[212]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[213]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[214]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[215]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[216]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[217]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[218]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[219]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[220]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[221]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[222]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[282]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[283]		= "IconSprites:Icon_Achievement_Achievement_Combat",
	[13	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_WeaponCrafting",
	[14	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Armorer",
	[15	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Outfitter",
	[16	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Tailor",
	[158]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Survivalist",
	[159]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Miner",
	[160]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_RelicHunter",
	[70	]		= "IconSprites:Icon_Achievement_Achievement_PvP",
	[71	]		= "IconSprites:Icon_Achievement_Achievement_PvP",
	[156]		= "IconSprites:Icon_Achievement_Achievement_PvP",
	[244]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[245]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[246]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[247]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[248]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[249]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[250]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[251]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[252]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[253]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[254]		= "IconSprites:Icon_Achievement_Achievement_Reputation",
	[19	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_WeaponCrafting",
	[20	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_WeaponCrafting",
	[21	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_WeaponCrafting",
	[22	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_WeaponCrafting",
	[23	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_WeaponCrafting",
	[286]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_WeaponCrafting",
	[25	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Armorer",
	[26	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Armorer",
	[27	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Armorer",
	[28	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Armorer",
	[29	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Armorer",
	[287]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Armorer",
	[31	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Outfitter",
	[32	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Outfitter",
	[33	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Outfitter",
	[41	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Outfitter",
	[42	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Outfitter",
	[288]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Outfitter",
	[34	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Tailor",
	[35	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Tailor",
	[43	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Tailor",
	[44	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Tailor",
	[45	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Tailor",
	[289]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Tailor",
	[36	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Architect",
	[37	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Architect",
	[57	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Architect",
	[58	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Architect",
	[59	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Architect",
	[293]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Architect",
	[294]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Architect",
	[38	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Technologist",
	[39	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Technologist",
	[54	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Technologist",
	[55	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Technologist",
	[56	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Technologist",
	[47	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Cooking",
	[76	]		= "IconSprites:Icon_Achievement_Achievement_Tradeskill_Cooking",
	[66	]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[166]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[169]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[172]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[67	]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[68	]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[153]		= "IconSprites:Icon_Achievement_Achievement_PvP",
	[154]		= "IconSprites:Icon_Achievement_Achievement_PvP",
	[155]		= "IconSprites:Icon_Achievement_Achievement_PvP",
	[149]		= "IconSprites:Icon_Achievement_Achievement_PvP",
	[150]		= "IconSprites:Icon_Achievement_Achievement_PvP",
	[79	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[82	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[85	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[88	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[91	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[94	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[80	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[81	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[83	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[84	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[86	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[87	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[89	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[90	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[92	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[95	]		= "IconSprites:Icon_Achievement_Achievement_Adventures",
	[259]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[260]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[261]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[262]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[263]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[264]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[265]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[266]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[267]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[268]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[269]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[272]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[273]		= "IconSprites:Icon_Achievement_Achievement_Challenges",
	[274]		= "IconSprites:Icon_Achievement_Achievement_Shiphand",
	[275]		= "IconSprites:Icon_Achievement_Achievement_Shiphand",
	[276]		= "IconSprites:Icon_Achievement_Achievement_Shiphand",
	[277]		= "IconSprites:Icon_Achievement_Achievement_Shiphand",
	[278]		= "IconSprites:Icon_Achievement_Achievement_Shiphand",
	[279]		= "IconSprites:Icon_Achievement_Achievement_Shiphand",
	[228]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[229]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[230]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[231]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[232]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[233]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[234]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[235]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[236]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[237]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[238]		= "IconSprites:Icon_Achievement_Achievement_WorldEvent",
	[165]		= "IconSprites:Icon_Achievement_Achievement_Raid",
	[239]		= "IconSprites:Icon_Achievement_Achievement_Raid",
	[167]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[168]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[170]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[171]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[173]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",
	[174]		= "IconSprites:Icon_Achievement_Achievement_Dungeon",

}

function Achievements:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Achievements:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- Achievements OnLoad
-----------------------------------------------------------------------------------------------

function Achievements:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Achievements.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Achievements:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
	
	Apollo.RegisterEventHandler("AchievementUpdated", 			"OnAchievementUpdated", self)
	Apollo.RegisterEventHandler("PL_ToggleAchievementWindow", 	"ToggleWindow", self)
	Apollo.RegisterEventHandler("PL_TabChanged", 				"OnCloseProgressLogTab", self)
	Apollo.RegisterEventHandler("AchievementGranted", 			"OnAchievementGranted", self)

	self.wndLastTopGroupSelected = nil
end

function Achievements:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_AchievementLog"), {"ToggleAchievementWindow", "Achievements", "Icon_Windows32_UI_CRB_InterfaceMenu_Achievements"})
end

function Achievements:OnAchievementUpdated(achUpdated) -- TODO: Pinpoint the redraw instead of a full redraw
	if not self.wndMain then
		return
	end

	if self.wndMain:FindChild("RightSummaryScreen"):IsShown() then
		self:LoadSummaryScreen()
	else
		local wndRightScroll = self.wndMain:FindChild("RightScroll")
		local nVScrollPos = wndRightScroll:GetVScrollPos()
		self:BuildRightPanel()
		wndRightScroll:SetVScrollPos(nVScrollPos)
	end
	self.wndMain:FindChild("BGLeft:HeaderPointsNumber"):SetText(AchievementsLib.GetAchievementPoints())
	self.wndMain:FindChild("BGLeft:HeaderPoints"):SetText(String_GetWeaselString(Apollo.GetString("Achievement_OverallPoints")))
end

function Achievements:ToggleWindow(achPassedAchievement)
	if self.wndMain then
		self:OnZoomToAchievementIfValid(achPassedAchievement)
		return	-- Prevent double loading
	end

	-- Load before it's opened in the ProgressLog for the Recently Updated list
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "AchievementsForm", g_wndProgressLog:FindChild("ContentWnd_4"), self)
	self.wndMain:FindChild("BGHeader:HeaderShowAllBtn"):SetCheck(true)

	local wndLeft = self.wndMain:FindChild("BGLeft")
	wndLeft:FindChild("HeaderPointsNumber"):SetText(AchievementsLib.GetAchievementPoints())
	wndLeft:FindChild("HeaderPoints"):SetText(String_GetWeaselString(Apollo.GetString("Achievement_OverallPoints")))
	wndLeft:FindChild("BtnTabPlayer"):SetCheck(true)

	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "TopGroup", nil, self)
	self.nTopGroupHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "MiddleGroup", nil, self)
	self.nMiddleGroupHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	wndMeasure = Apollo.LoadForm(self.xmlDoc, "BottomItem", nil, self)
	self.nBottomItemHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	self.bShowGuild = achPassedAchievement and achPassedAchievement:IsGuildAchievement() or false

	self:BuildCategoryTree()
	self:LoadSummaryScreen()
	self:OnZoomToAchievementIfValid(achPassedAchievement)
end

function Achievements:BuildCategoryTree()
	local tCategoryTree = AchievementsLib.GetAchievementCategoryTree(self.bShowGuild)
	if not tCategoryTree then
		return
	end

	table.sort(tCategoryTree, function(a,b) return a.strCategoryName < b.strCategoryName end)

	-- Top Summary Group
	local wndLeftScroll = self.wndMain:FindChild("BGLeft:LeftScroll")
	self.wndSummaryGroup = self:LoadByName("TopGroup", wndLeftScroll, "TopSummaryGroup")
	self.wndSummaryGroup:FindChild("TopGroupBtn"):ChangeArt("btnMetal_ExpandMenu_LargeArrow")
	self.wndSummaryGroup:FindChild("TopGroupBtn"):FindChild("GroupTitle"):SetText(Apollo.GetString("Achievements_SummaryBtn"))

	-- All resizing we'll do on the collapse/expand methods
	for key, tTopLevel in pairs(tCategoryTree) do
		local wndTopGroup = Apollo.LoadForm(self.xmlDoc, "TopGroup", wndLeftScroll, self)
		local wndTopContents = wndTopGroup:FindChild("GroupContents")

		for key2, tMiddleLevel in pairs(tTopLevel.tGroups) do
			local wndMiddleGroup = Apollo.LoadForm(self.xmlDoc, "MiddleGroup", wndTopContents, self)
			local wndMidContents = wndMiddleGroup:FindChild("GroupContents")

			for key3, tLowLevel in pairs(tMiddleLevel.tSubGroups) do
				local wndBottomItem = Apollo.LoadForm(self.xmlDoc, "BottomItem", wndMidContents, self)
				wndBottomItem:SetData(tLowLevel.nSubGroupId)

				local wndBottomItemBtn = wndBottomItem:FindChild("BottomItemBtn")
				wndBottomItemBtn:SetData({wndTopGroup, tLowLevel.nSubGroupId, wndMiddleGroup}) -- To ensure top level is always checked
				wndBottomItemBtn:FindChild("GroupTitle"):SetText(tLowLevel.strSubGroupName)
			end

			local bMiddleGroupHasChildren = #wndMidContents:GetChildren() > 0
			local wndMiddleGroupBtn = wndMiddleGroup:FindChild("MiddleGroupBtn")
			wndMiddleGroupBtn:SetData({wndTopGroup, tMiddleLevel.nGroupId}) -- To ensure top level is always checked
			wndMiddleGroupBtn:FindChild("GroupTitle"):SetText(tMiddleLevel.strGroupName)
			wndMiddleGroupBtn:ChangeArt(bMiddleGroupHasChildren and "BK3:btnMetal_ExpandMenu_Med" or "BK3:btnMetal_ExpandMenu_MedClean")

			wndMiddleGroup:SetData(tMiddleLevel.nGroupId)
			wndMiddleGroup:FindChild("MiddleExpandBtn"):SetData(wndMiddleGroup)
			wndMiddleGroup:FindChild("MiddleExpandBtn"):Show(tMiddleLevel and #tMiddleLevel.tSubGroups > 0 and false)
			wndMidContents:ArrangeChildrenVert(0)
		end

		local bTopGroupHasChildren = #wndTopContents:GetChildren() > 0
		local wndTopGroupBtn = wndTopGroup:FindChild("TopGroupBtn")
		wndTopGroupBtn:SetData({wndTopGroup, tTopLevel.nCategoryId})
		wndTopGroupBtn:FindChild("GroupTitle"):SetText(tTopLevel.strCategoryName)
		wndTopGroupBtn:ChangeArt(bTopGroupHasChildren and "BK3:btnMetal_ExpandMenu_Large" or "BK3:btnMetal_ExpandMenu_LargeClean")

		wndTopGroup:SetData(tTopLevel.nCategoryId)
		wndTopContents:ArrangeChildrenVert(0)
	end

	self:ResizeTree()
end

-----------------------------------------------------------------------------------------------
-- Left Tree Panel
-----------------------------------------------------------------------------------------------

function Achievements:ResizeTree()
	local wndLeftScroll = self.wndMain:FindChild("BGLeft:LeftScroll")
	
	for key, wndTopGroup in pairs(wndLeftScroll:GetChildren()) do
		local wndTopContents = wndTopGroup:FindChild("GroupContents")
		local wndTopButton = wndTopGroup:FindChild("TopGroupBtn")
		local nMiddleHeight = 0

		if wndTopButton:IsChecked() and wndTopContents:IsShown() then
			for key2, wndMiddleGroup in pairs(wndTopContents:GetChildren()) do
				local nBottomHeight = 0
				if wndMiddleGroup:FindChild("MiddleExpandBtn"):IsChecked() then
					wndTopButton:SetCheck(true)
					nBottomHeight = wndMiddleGroup:FindChild("GroupContents"):ArrangeChildrenVert(0)

					if nBottomHeight > 0 then
						nBottomHeight = nBottomHeight + 15
					end
				else
					--wndMiddleGroup:FindChild("GroupContents"):DestroyChildren()
				end

				local nLeft, nTop, nRight, nBottom = wndMiddleGroup:GetAnchorOffsets()
				wndMiddleGroup:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nBottomHeight + self.nMiddleGroupHeight)
				nMiddleHeight = nMiddleHeight + nBottomHeight + self.nMiddleGroupHeight
			end

			if nMiddleHeight > 0 then
				nMiddleHeight = nMiddleHeight + 25
			end
		end

		local nLeft, nTop, nRight, nBottom = wndTopGroup:GetAnchorOffsets()
		wndTopGroup:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nMiddleHeight + self.nTopGroupHeight)
		wndTopContents:ArrangeChildrenVert(0)
	end

	wndLeftScroll:ArrangeChildrenVert(0)
end

function Achievements:UnselectAll() -- TODO: REFACTOR, this mostly simulates a global radio group
	for key, wndTop in pairs(self.wndMain:FindChild("BGLeft:LeftScroll"):GetChildren()) do
		local wndTopGroupBtn = wndTop:FindChild("TopGroupBtn")
		wndTop:FindChild("GroupContents"):Show(false)
		wndTopGroupBtn:SetCheck(false)
		wndTopGroupBtn:FindChild("GroupTitle"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
		for key2, wndMid in pairs(wndTop:FindChild("GroupContents"):GetChildren()) do
			local wndMidGroupBtn = wndMid:FindChild("MiddleGroupBtn")
			wndMidGroupBtn:SetCheck(false)
			wndMid:FindChild("MiddleExpandBtn"):SetCheck(false)
			wndMidGroupBtn:FindChild("GroupTitle"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
			for key3, wndBot in pairs(wndMid:FindChild("GroupContents"):GetChildren()) do
				local wndBotItemBtn = wndBot:FindChild("BottomItemBtn")
				wndBotItemBtn:SetCheck(false)
				wndBotItemBtn:FindChild("GroupTitle"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
			end
		end
	end
end

function Achievements:OnTopGroupSelect(wndHandler, wndControl)
	-- wndHandler is "TopGroupBtn" or self.wndSummaryGroup, and its data is {wndTopGroup, nCategoryId}
	-- TODO: Quick hack: Both the select and unselect route here to simulate DisallowUnselect
	if wndHandler == self.wndSummaryGroup:FindChild("TopGroupBtn") or self.wndLastTopGroupSelected == wndControl then
		self:LoadSummaryScreen()
		self.wndLastTopGroupSelected = self.wndSummaryGroup:FindChild("TopGroupBtn")
		return
	elseif not wndHandler or not wndHandler:GetData() then
		return
	end

	self.wndLastTopGroupSelected = wndControl
	self:LoadRightScreenFromLeftScreen(wndHandler)
end

function Achievements:OnMiddleGroupSelect(wndHandler, wndControl)
	-- wndHandler is "MiddleGroupBtn" and its data is {wndTopGroup, nCategoryId}
	-- TODO: Quick hack: Both the select and unselect route here to simulate DisallowUnselect
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	self:LoadRightScreenFromLeftScreen(wndHandler)

	-- Middle Expanding
	wndHandler:GetParent():FindChild("MiddleExpandBtn"):SetCheck(wndHandler:IsChecked()) -- TODO hack
	if wndHandler:IsChecked() then -- If something below was clicked, promote it to the middle
		for key, wndCurr in pairs(wndHandler:GetData()[1]:FindChild("GroupContents"):GetChildren()) do
			if wndCurr:FindChild("BottomItemBtn") and wndCurr:FindChild("BottomItemBtn"):IsChecked() then
				self:LoadRightScreenFromLeftScreen(wndHandler:GetData()[1]:FindChild("MiddleGroupBtn"))
			end
		end
	end
	

	self:ResizeTree()
end

function Achievements:OnBottomItemSelect(wndHandler, wndControl)
	-- wndHandler is "BottomItemBtn", and its data is {wndTopGroup, nCategoryId, wndMiddleGroup}
	-- TODO: Quick hack: Both the select and unselect route here to simulate DisallowUnselect
	if not wndHandler or not wndHandler:GetData() then
		return
	end

	self:LoadRightScreenFromLeftScreen(wndHandler)
end

function Achievements:LoadRightScreenFromLeftScreen(wndCurr)
	local wndTopGroup = wndCurr:GetData()[1]
	local idCategory = wndCurr:GetData()[2]
	local wndMiddleGroup = wndCurr:GetData()[3]
	local wndHeader = self.wndMain:FindChild("BGHeader")

	wndHeader:FindChild("HeaderSearchBox"):ClearFocus()

	-- Update checks
	local bIsChecked = wndCurr:IsChecked()
	self:UnselectAll()
	wndCurr:SetCheck(bIsChecked)
	if wndTopGroup:FindChild("TopGroupBtn") then
		wndTopGroup:FindChild("TopGroupBtn"):SetCheck(true)
	end
	
	if wndMiddleGroup then
		wndMiddleGroup:FindChild("MiddleExpandBtn"):SetCheck(true)
		wndMiddleGroup:FindChild("MiddleGroupBtn"):SetCheck(true)
	end
	wndCurr:FindChild("GroupTitle"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))

	-- Update window visibilities
	wndTopGroup:FindChild("GroupContents"):Show(true)
	self.wndMain:FindChild("RightSummaryScreen"):Show(false)

	wndHeader:Show(true)
	self:ResizeTree()

	-- Build, if it isn't a duplicate clicks
	if self.wndMain:FindChild("RightScroll"):GetData() == idCategory then
		wndHeader:FindChild("HeaderShowAllBtn"):Enable(true)
		wndHeader:FindChild("HeaderOngoingBtn"):Enable(true)
		wndHeader:FindChild("HeaderCompleteBtn"):Enable(true)
	else
		self.wndMain:FindChild("RightScroll"):SetData(idCategory)
		self:BuildRightPanel()
	end
end

-----------------------------------------------------------------------------------------------
-- Summary Screen
-----------------------------------------------------------------------------------------------

function Achievements:LoadSummaryScreen() -- TODO: Figure out why this is being called called when the Achievement list is filtered/built
	self:UnselectAll()
	local wndTopGroupBtn = self.wndSummaryGroup:FindChild("TopGroupBtn")
	if wndTopGroupBtn then
		wndTopGroupBtn:SetCheck(true)
	end

	wndTopGroupBtn:FindChild("GroupTitle"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
	self.wndMain:FindChild("RightSummaryScreen"):Show(true)

	local wndHeader = self.wndMain:FindChild("BGHeader")
	wndHeader:Show(false)
	wndHeader:FindChild("HeaderShowAllBtn"):Enable(false)
	wndHeader:FindChild("HeaderOngoingBtn"):Enable(false)
	wndHeader:FindChild("HeaderCompleteBtn"):Enable(false)
	self:ResizeTree()

	-- Build last updated
	local wndRecentUpdateContainer = self.wndMain:FindChild("RightSummaryScreen:RecentUpdateFrame:RecentUpdateContainer")
	wndRecentUpdateContainer:DestroyChildren()
	local tRecent = AchievementsLib.GetRecentCompletedAchievements(6, self.bShowGuild)
	for idx, achUpdated in pairs(tRecent) do
		local wndListItem = Apollo.LoadForm(self.xmlDoc, "RecentUpdateItem", wndRecentUpdateContainer, self)
		wndListItem:FindChild("RecentUpdateBtn"):SetData(achUpdated)
		wndListItem:FindChild("RecentUpdateName"):SetText(achUpdated:GetName())
		local nOldHeight = wndListItem:FindChild("RecentUpdateName"):GetHeight()
		wndListItem:FindChild("RecentUpdateName"):SetHeightToContentHeight()
		if wndListItem:FindChild("RecentUpdateName"):GetHeight() > nOldHeight then
			local nListItemLeft, nListItemTop, nListItemRight, nListItemBottom = wndListItem:GetAnchorOffsets()
			wndListItem:SetAnchorOffsets(nListItemLeft, nListItemTop, nListItemRight, nListItemBottom + wndListItem:FindChild("RecentUpdateName"):GetHeight() - nOldHeight)
		end
		wndListItem:FindChild("RecentUpdatePoints"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_PointValue"), achUpdated:GetPoints()))
	end
	wndRecentUpdateContainer:ArrangeChildrenVert(0)

	-- Build overall progress
	local tCategoryTree = AchievementsLib.GetAchievementCategoryTree(self.bShowGuild)
	if not tCategoryTree then
		return
	end

	local wndSummaryContainer = self.wndMain:FindChild("RightSummaryScreen:SummaryContainerFrame:SummaryContainer")
	wndSummaryContainer:DestroyChildren() -- TODO remove
	for key, tTopLevel in pairs(tCategoryTree) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "SummaryItem", wndSummaryContainer, self)
		local tAchievements = AchievementsLib.GetAchievementsForCategory(tTopLevel.nCategoryId, true, self.bShowGuild) -- True to recurse
		local nTotal = 0
		local nComplete = 0
		for key2, achCurr in pairs(tAchievements) do -- TODO: refactor, this is expensive
			nTotal = nTotal + 1
			if achCurr:IsComplete() then
				nComplete = nComplete + 1
			end
		end
		wndCurr:SetData(tTopLevel.strCategoryName)
		local wndSummaryProgress = wndCurr:FindChild("SummaryItemProg")
		wndSummaryProgress:SetMax(nTotal)
		wndSummaryProgress:SetProgress(nComplete)
		wndSummaryProgress:EnableGlow(nComplete > 0)
		wndCurr:FindChild("SummaryItemName"):SetText(tTopLevel.strCategoryName)
		wndCurr:FindChild("SummaryItemStatus"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Progress"), nComplete, nTotal))
	end
	wndSummaryContainer:ArrangeChildrenTiles(0, function(a,b) return (a:GetData() < b:GetData()) end) -- TODO: refactor, this is expensive
end

function Achievements:OnRecentUpdateBtn(wndHandler, wndControl)
	-- Update top filter states. TODO refactor:
	local wndHeader = self.wndMain:FindChild("BGHeader")
	local wndRightScroll = self.wndMain:FindChild("RightScroll")
	local wndSearchBox = wndHeader:FindChild("HeaderSearchBox")
	local wndShowAll = wndHeader:FindChild("HeaderShowAllBtn")
	local wndOngoing = self.wndMain:FindChild("HeaderOngoingBtn")
	local wndComplete = self.wndMain:FindChild("HeaderCompleteBtn")

	wndRightScroll:SetData(0)
	wndSearchBox:SetText("")
	wndSearchBox:ClearFocus()
	wndShowAll:Enable(true)
	wndOngoing:Enable(true)
	wndComplete:Enable(true)
	wndShowAll:SetCheck(true)
	wndOngoing:SetCheck(false)
	wndComplete:SetCheck(false)

	self:OnZoomToAchievementIfValid(wndHandler:GetData())
	local wndTarget = wndRightScroll:FindChildByUserData(wndHandler:GetData())
	wndRightScroll:EnsureChildVisible(wndTarget)
end

function Achievements:OnZoomToAchievementIfValid(achArg)
	if not achArg or not achArg:GetCategoryId() then
		return
	end

	if achArg:IsGuildAchievement() ~= self.bShowGuild then
		self.bShowGuild = achArg:IsGuildAchievement()
		self:BuildCategoryTree()
		self:LoadSummaryScreen()
	end

	local idArgCategory = achArg:GetCategoryId()
	for key, wndTopGroup in pairs(self.wndMain:FindChild("BGLeft:LeftScroll"):GetChildren()) do
		if wndTopGroup:GetData() == idArgCategory then
			self:OnTopGroupSelect(wndTopGroup:FindChild("TopGroupBtn"))
			return
		end

		for key2, wndMiddleGroup in pairs(wndTopGroup:FindChild("GroupContents"):GetChildren()) do
			if wndMiddleGroup:GetData() == idArgCategory then
				self:OnBottomItemSelect(wndMiddleGroup:FindChild("MiddleGroupBtn"))
				return
			end

			for key3, wndBottomGroup in pairs(wndMiddleGroup:FindChild("GroupContents"):GetChildren()) do
				if wndBottomGroup:GetData() == idArgCategory then
					wndMiddleGroup:FindChild("MiddleExpandBtn"):SetCheck(true)
					self:ResizeTree()
					self:OnBottomItemSelect(wndBottomGroup:FindChild("BottomItemBtn"))
					return
				end
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Right Panel
-----------------------------------------------------------------------------------------------

function Achievements:OnHeaderFilterBtn() -- Route through here so we know when to clear the search focus (and more importantly, when not to)
	self.wndMain:FindChild("BGHeader:HeaderSearchBox"):ClearFocus()
	self:BuildRightPanel()
end


function Achievements:BuildRightPanel()
	local wndRightScroll = self.wndMain:FindChild("RightScroll")
	local tAchievements = AchievementsLib.GetAchievementsForCategory(wndRightScroll:GetData(), true, self.bShowGuild) -- True to recurse
	if not tAchievements then
		return
	end

	local wndHeader = self.wndMain:FindChild("BGHeader")
	wndHeader:FindChild("HeaderShowAllBtn"):Enable(true)
	wndHeader:FindChild("HeaderOngoingBtn"):Enable(true)
	wndHeader:FindChild("HeaderCompleteBtn"):Enable(true)
	wndHeader:FindChild("ClearSearchBtn"):Show(wndHeader:FindChild("HeaderSearchBox"):GetText() ~= "")
	wndRightScroll:DestroyChildren() -- TODO: Remove
	wndRightScroll:RecalculateContentExtents()

	local tAdded = {} -- Achievement Id's to wndTierBox
	local tDoLaterList = {} -- Achievement Id's to Achievement Objects
	for key, achCurr in pairs(tAchievements) do
		if not tDoLaterList[achCurr:GetId()] and not tAdded[achCurr:GetId()] and self:HelperCheckFilters(achCurr) then

			-- There are three types: Tiered, Checklist, Normal
			if achCurr:IsChecklist() then
				self:BuildChecklistAchievement(achCurr)
			elseif achCurr:GetParentTier() then
				-- Find and build the top most parent. Put everything else in a do later list.
				tDoLaterList[achCurr:GetId()] = achCurr

				local achTopMostParent = achCurr:GetParentTier()
				local nSafetyCount = 0
				while achTopMostParent:GetParentTier() and nSafetyCount < 99 do
					nSafetyCount = nSafetyCount + 1
					tDoLaterList[achTopMostParent:GetId()] = achTopMostParent
					achTopMostParent = achTopMostParent:GetParentTier()
				end

				if not tAdded[achTopMostParent:GetId()] then
					local wndExisting = wndRightScroll:FindChildByUserData(achTopMostParent)
					if wndExisting then
						wndExisting:Destroy()
					end
					local wndTieredAchievement = self:BuildTieredAchievement(achTopMostParent)
					tAdded[achTopMostParent:GetId()] = wndTieredAchievement
					self:BuildTieredItem(achTopMostParent, wndTieredAchievement)
				end
			else
				local wndAchievement = Apollo.LoadForm(self.xmlDoc, "AchievementSimple", wndRightScroll, self)
				self:BuildSimpleAchievement(wndAchievement, achCurr)
				wndAchievement:SetData(achCurr)
			end
		end
	end

	local nSafetyCount = 0
	while self:GetTableSize(tDoLaterList) > 0 and nSafetyCount < 99 do
		nSafetyCount = nSafetyCount + 1
		for idx, achCurr in pairs(tDoLaterList) do
			local wndTierBox = tAdded[achCurr:GetParentTier():GetId()]
			if wndTierBox then
				self:BuildTieredItem(achCurr, wndTierBox)
				tAdded[achCurr:GetId()] = wndTierBox
				tDoLaterList[idx] = nil
			end
		end
	end

	if nSafetyCount >= 99 then
		for idx, achNotFound in pairs(tDoLaterList) do
			Print(String_GetWeaselString(Apollo.GetString("Achievement_UnknownAchievement"), achNotFound:GetId(), achNotFound:GetName()))
		end
	end

	-- Find the best default tiered entry to check
	for key, wndTop in pairs(wndRightScroll:GetChildren()) do
		local wndTierBox = wndTop:FindChild("AchievementExtraContainer:TierBox")
		if wndTierBox then
			local nTableSize = #wndTierBox:GetChildren()
			for idx, wndCurrTier in pairs(wndTierBox:GetChildren()) do
				if not wndCurrTier:GetData():IsComplete() or idx == nTableSize then
					wndCurrTier:FindChild("TierItemBtn"):SetCheck(true)

					local achCurrent = wndCurrTier:GetData()
					self:BuildSimpleAchievement(wndTop, achCurrent)
					wndTop:SetData(achCurrent)

					if not achCurrent:IsComplete() then
						local strTitleText = String_GetWeaselString(Apollo.GetString("Achievements_IncompleteTitle"), achCurrent:GetName(), self:HelperNumberToRomanNumerals(idx))
						wndTop:FindChild("AchievementExpanderBtn"):SetCheck(true)
						wndTop:FindChild("TitleText"):SetText(strTitleText)
						self:OnAchievementExpand(wndTop)
					end
					break
				end
			end
		end
	end

	self.wndMain:FindChild("RightEmptyMessage"):Show(#wndRightScroll:GetChildren() == 0)
	wndRightScroll:ArrangeChildrenVert(0, function(a,b) return a:GetData():IsComplete() end)
	wndRightScroll:RecalculateContentExtents()
end

function Achievements:BuildSimpleAchievement(wndContainer, achData)
	local nNumNeeded = achData:GetNumNeeded()
	local nNumCompleted = achData:GetNumCompleted()
	local bShowProgressBar = achData:IsChecklist() or achData:GetChildTier() or achData:GetParentTier() or (nNumNeeded > 1 and not achData:IsComplete())

	local wndTierBox = wndContainer:FindChild("AchievementExtraContainer:TierBox")
	if wndTierBox then
		local tTiers = wndTierBox:GetChildren()
		for idx = 1, #tTiers do
			if tTiers[idx]:GetData() == achData then
				local strTitleText = String_GetWeaselString(Apollo.GetString("Achievements_IncompleteTitle"), achData:GetName(), self:HelperNumberToRomanNumerals(idx))
				wndContainer:FindChild("TitleText"):SetText(strTitleText)
				break
			end
		end
	else
		wndContainer:FindChild("TitleText"):SetText(achData:GetName())
	end
	
	local nId = achData:GetCategoryId()
	wndContainer:FindChild("AchievementIcon"):SetSprite(ktAchievementIconsText[achData:GetCategoryId()])
	if achData:IsComplete() then
		nNumCompleted = nNumNeeded
		wndContainer:FindChild("TitleText"):SetTextColor(ApolloColor.new("UI_BtnTextGreenNormal"))
		wndContainer:FindChild("PointsText"):SetTextColor(ApolloColor.new("UI_BtnTextGreenNormal"))
		wndContainer:FindChild("DescriptionText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBodyCyan\">"..achData:GetDescription().."</P>")

		local strTooltipCompleted = String_GetWeaselString(Apollo.GetString("Achievements_CompletedDate"), achData:GetDateCompleted())
		wndContainer:SetTooltip(string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", strTooltipCompleted))
	else
		wndContainer:FindChild("DescriptionText"):SetAML("<P Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBodyCyan\">"..achData:GetProgressText().."</P>")
		wndContainer:FindChild("TitleText"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))
		wndContainer:FindChild("PointsText"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
		wndContainer:SetTooltip("")
	end
	
	-- Resize based on description height
	local nDescHeight = wndContainer:FindChild("DescriptionText"):GetHeight()
	wndContainer:FindChild("DescriptionText"):SetHeightToContentHeight()
	if wndContainer:FindChild("DescriptionText"):GetHeight() > nDescHeight then
		local nOffset = wndContainer:FindChild("DescriptionText"):GetHeight() - nDescHeight + 10
		local nLeft, nTop, nRight, nBottom = wndContainer:GetAnchorOffsets()
		wndContainer:SetAnchorOffsets(nLeft, nTop, nRight, nBottom + nOffset)
		nLeft, nTop, nRight, nBottom = wndContainer:FindChild("AchievementExtraContainer"):GetAnchorOffsets()
		wndContainer:FindChild("AchievementExtraContainer"):SetAnchorOffsets(nLeft, nTop + nOffset, nRight, nBottom)
	end

	wndContainer:FindChild("AchievementCheck"):Show(achData:IsComplete())
	wndContainer:FindChild("PointsText"):SetText(achData:GetPoints())

	local wndProgressBarContainer = wndContainer:FindChild("AchievementProgressBarContainer")
	wndProgressBarContainer:Show(bShowProgressBar)
	if achData:IsCurrencyShown() then
		wndProgressBarContainer:FindChild("NeededCompletedText"):Show(false)
		wndProgressBarContainer:FindChild("NeededCompletedCash"):Show(true)
		wndProgressBarContainer:FindChild("NeededCompletedCash"):SetMoneySystem(achData:GetCurrencySystem())
		wndProgressBarContainer:FindChild("NeededCompletedCash"):SetAmount(nNumCompleted)
	else
		wndProgressBarContainer:FindChild("NeededCompletedText"):Show(true)
		wndProgressBarContainer:FindChild("NeededCompletedCash"):Show(false)
		wndProgressBarContainer:FindChild("NeededCompletedText"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), nNumCompleted, nNumNeeded))
	end
	
	if not bShowProgressBar then
		local nLeft, nTop, nRight, nBottom = wndContainer:GetAnchorOffsets()
		wndContainer:SetAnchorOffsets(nLeft, nTop, nRight, nBottom - wndProgressBarContainer:GetHeight() + 10)
	end

	local wndProgressBar = wndContainer:FindChild("NeededCompletedProgressBar")
	wndProgressBar:SetMax(nNumNeeded)
	wndProgressBar:SetProgress(nNumCompleted)
	wndProgressBar:EnableGlow(nNumCompleted > 0)

	-- Rewards
	wndContainer:FindChild("RewardsContainer"):DestroyChildren()
	local tRewards = achData:GetRewards()
	if tRewards and tRewards.strTitle then -- TODO: Other types. Only Titles are supported right now
		local wndReward = Apollo.LoadForm(self.xmlDoc, "LootItem", wndContainer:FindChild("RewardsContainer"), self)
		wndReward:FindChild("LootIcon"):Show(false)
		wndReward:FindChild("LootIconPicture"):Show(true)
		wndReward:FindChild("LootIconPicture"):SetTooltip(String_GetWeaselString(Apollo.GetString("Achievements_RewardTitle"), tRewards.strTitle:GetTitle()))
	end
	wndContainer:FindChild("RewardsContainer"):ArrangeChildrenHorz(2)
end

function Achievements:BuildChecklistAchievement(achData)
	local wndContainer = Apollo.LoadForm(self.xmlDoc, "AchievementSimple", self.wndMain:FindChild("RightScroll"), self)
	local wndGrid = Apollo.LoadForm(self.xmlDoc, "ChecklistGrid", wndContainer:FindChild("AchievementExtraContainer"), self)
	self:BuildSimpleAchievement(wndContainer, achData)
	wndContainer:SetData(achData)

	wndContainer:FindChild("AchievementExpanderBtn"):Show(true)
	wndContainer:FindChild("AchievementExpanderBtn"):SetData(wndContainer)

	if not achData:IsComplete() then
		wndContainer:FindChild("AchievementExpanderBtn"):SetCheck(true)
		self:OnAchievementExpand(wndContainer)
	end

	for key, tCurr in pairs(achData:GetChecklistItems()) do
		local iCurrRow = wndGrid:AddRow("")
		if tCurr.bIsComplete then
			wndGrid:SetCellImage(iCurrRow, 1, "IconSprites:Icon_Windows16_BulletPoint_Checked")
			wndGrid:SetCellDoc(iCurrRow, 2, string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"UI_BtnTextGreenNormal\">%s</T>", tCurr.strChecklistEntry))
		else
			wndGrid:SetCellImage(iCurrRow, 1, "IconSprites:Icon_Windows16_BulletPoint_Grey")
			wndGrid:SetCellDoc(iCurrRow, 2, string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBodyCyan\">%s</T>", tCurr.strChecklistEntry))
		end
	end
end

function Achievements:BuildTieredAchievement(achData)
	local wndContainer = Apollo.LoadForm(self.xmlDoc, "AchievementSimple", self.wndMain:FindChild("RightScroll"), self)
	local wndTierBox = Apollo.LoadForm(self.xmlDoc, "TierBox", wndContainer:FindChild("AchievementExtraContainer"), self)
	self:BuildSimpleAchievement(wndContainer, achData)
	wndContainer:SetData(achData)

	wndContainer:FindChild("AchievementExpanderBtn"):Show(true)
	wndContainer:FindChild("AchievementExpanderBtn"):SetData(wndContainer)

	return wndTierBox
end

function Achievements:BuildTieredItem(achData, wndTierBox)
	local wndTierItem = Apollo.LoadForm(self.xmlDoc, "TierItem", wndTierBox, self)
	local wndTierBtn = wndTierItem:FindChild("TierItemBtn")
	wndTierItem:SetData(achData)
	wndTierBtn:FindChild("TierItemIconCheck"):Show(achData:IsComplete())
	wndTierItem:FindChild("TierItemBtn"):SetData(wndTierBox:GetParent():GetParent()) -- TODO refactor
	
	if achData:IsCurrencyShown() then
		wndTierItem:FindChild("TierItemCash"):Show(true)
		wndTierItem:FindChild("TierItemNeeded"):Show(false)
		wndTierItem:FindChild("TierItemCash"):SetMoneySystem(achData:GetCurrencySystem())
		wndTierItem:FindChild("TierItemCash"):SetAmount(achData:GetNumNeeded())
	else
		wndTierItem:FindChild("TierItemCash"):Show(false)
		wndTierItem:FindChild("TierItemNeeded"):Show(true)
		wndTierItem:FindChild("TierItemNeeded"):SetText(Apollo.FormatNumber(achData:GetNumNeeded(), 0, true))
	end

	if achData:IsComplete() then
		local strCompleteDate = String_GetWeaselString(Apollo.GetString("Achievements_CompletedDate"), achData:GetDateCompleted())
		wndTierItem:FindChild("TierItemNeeded"):SetTextColor(ApolloColor.new("ff5f6662"))
		wndTierItem:FindChild("TierItemCash"):SetTextColor(ApolloColor.new("ff5f6662"))
		wndTierBtn:FindChild("TierItemIcon"):SetTooltip(string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", strCompleteDate))
	else
		wndTierItem:FindChild("TierItemNeeded"):SetTextColor(ApolloColor.new("ff2f94ac"))
		wndTierItem:FindChild("TierItemCash"):SetTextColor(ApolloColor.new("ff2f94ac"))
		wndTierBtn:FindChild("TierItemIcon"):SetTooltip(string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", achData:GetName()))

	end
	wndTierBox:ArrangeChildrenHorz(0)
end

function Achievements:OnTierItemCheck(wndHandler, wndControl) -- wndHandler is "TierItemBtn"
	-- TODO: Quick hack: Both the select and unselect route here to simulate DisallowUnselect
	self.wndMain:FindChild("BGHeader:HeaderSearchBox"):ClearFocus()

	local wndTop = wndHandler:GetData() -- This should be "SimpleAchievement"
	if wndTop then
		local wndParent = wndHandler:GetParent()
		local achSelected = wndParent:GetData()
		self:BuildSimpleAchievement(wndTop, achSelected)
	end

	for key, wndCurr in pairs(wndTop:FindChild("AchievementExtraContainer:TierBox"):GetChildren()) do -- TEMP
		wndCurr:FindChild("TierItemBtn"):SetCheck(false)
	end
	wndHandler:SetCheck(true)
end

function Achievements:OnAchievementExpanderBtn(wndHandler, wndControl) -- the actual button so we can clear search
	self.wndMain:FindChild("BGHeader:HeaderSearchBox"):ClearFocus()
	self:OnAchievementExpand(wndHandler:GetData() or wndHandler:GetParent()) -- TODO refactor
end

function Achievements:OnAchievementExpand(wndParent) -- the function it triggers
	local achSelected = wndParent:GetData()
	local bButtonChecked = wndParent:FindChild("AchievementExpanderBtn"):IsChecked()

	local nLeft, nTop, nRight, nBottom = wndParent:GetAnchorOffsets()
	if achSelected:IsChecklist() and bButtonChecked then
		nBottom = nBottom + (8 + #achSelected:GetChecklistItems() * 20) -- TODO hardcoded formatting
	elseif achSelected:IsChecklist() and not bButtonChecked then
		nBottom = nBottom - (8 + #achSelected:GetChecklistItems() * 20)
	elseif bButtonChecked then
		nBottom = nBottom + 82
	else
		nBottom = nBottom - 82
	end

	wndParent:SetAnchorOffsets(nLeft, nTop, nRight, nBottom)
	wndParent:FindChild("AchievementExtraContainer"):Show(bButtonChecked)

	self.wndMain:FindChild("RightScroll"):ArrangeChildrenVert(0)
end

function Achievements:OnClearSearchBtn(wndHandler, wndControl)
	local wndHeader = self.wndMain:FindChild("BGHeader")
	wndHeader:FindChild("ClearSearchBtn"):Show(false)
	local wndSearchBox = wndHeader:FindChild("HeaderSearchBox")
	wndSearchBox:SetText("")
	wndSearchBox:ClearFocus()
	self:BuildRightPanel()
end

function Achievements:OnTabPlayerBtn(wndHandler, wndControl, eMouseButton)
	self.bShowGuild = false

	self.wndMain:FindChild("RightScroll"):SetData(nil)
	self.wndMain:FindChild("BGLeft:LeftScroll"):DestroyChildren()
	self.wndMain:FindChild("BGLeft:HeaderPointsNumber"):SetText(AchievementsLib.GetAchievementPoints())
	self.wndMain:FindChild("BGLeft:HeaderPoints"):SetText(String_GetWeaselString(Apollo.GetString("Achievement_OverallPoints")))
	self:BuildCategoryTree()
	self:LoadSummaryScreen()
end

function Achievements:OnTabGuildBtn(wndHandler, wndControl, eMouseButton)
	self.bShowGuild = true

	self.wndMain:FindChild("RightScroll"):SetData(nil)
	self.wndMain:FindChild("BGLeft:LeftScroll"):DestroyChildren()
	self:BuildCategoryTree()
	self:LoadSummaryScreen()
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function Achievements:HelperCheckFilters(achFiltered)
	local bResult = false
	local wndHeader = self.wndMain:FindChild("BGHeader")
	if wndHeader:FindChild("HeaderShowAllBtn"):IsChecked() then
		bResult = true
	elseif wndHeader:FindChild("HeaderOngoingBtn"):IsChecked() and not achFiltered:IsComplete() then
		bResult = true
	elseif wndHeader:FindChild("HeaderCompleteBtn"):IsChecked() and achFiltered:IsComplete() then
		bResult = true
	end

	-- Check for complete filters
	if wndHeader:FindChild("RewardFilterBtn"):IsChecked() and bResult then
		local tRewards = achFiltered:GetRewards()
		bResult = tRewards ~= nil and tRewards.strTitle
	end

	local strSearchString = wndHeader:FindChild("HeaderSearchBox"):GetText():lower()
	if bResult and strSearchString then
		-- Find the first character of a word or an exact match from the start
		local strAchieveName = achFiltered:GetName():lower()
		bResult = strAchieveName:find(" "..strSearchString, 1, true) or string.sub(strAchieveName, 0, string.len(strSearchString)) == strSearchString
	end

	return bResult
end

function Achievements:GetTableSize(tArg)
    local nCounter = 0
    if tArg ~= nil then
        for key, value in pairs(tArg) do
            nCounter = nCounter + 1
        end
    end
    return nCounter
end

function Achievements:HelperNumberToRomanNumerals(nValue)
	local strRoman = ""
    for i = #kaRomanNumeralNumbers, 1, -1 do
        local nCurrentNum = kaRomanNumeralNumbers[i]
        while nValue - nCurrentNum >= 0 and nValue > 0 do
            strRoman = strRoman .. kaRomanNumeralChars[i]
            nValue = nValue - nCurrentNum
        end
        for j = 1, i - 1 do
            local n2 = kaRomanNumeralNumbers[j]
            if nValue - (nCurrentNum - n2) >= 0 and nValue < nCurrentNum and nValue > 0 and nCurrentNum - n2 ~= n2 then
                strRoman = strRoman .. kaRomanNumeralChars[j] .. kaRomanNumeralChars[i]
                nValue = nValue - (nCurrentNum - n2)
                break
            end
        end
    end
    return strRoman
end

function Achievements:LoadByName(strForm, wndParent, strCustomName)
	local wndNew = wndParent:FindChild(strCustomName)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strForm, wndParent, self)
		wndNew:SetName(strCustomName)
	end
	return wndNew
end

local AchievementsInst = Achievements:new()
AchievementsInst:Init()
