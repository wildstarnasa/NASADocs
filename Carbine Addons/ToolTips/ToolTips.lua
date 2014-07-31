-----------------------------------------------------------------------------------------------
-- Client Lua Script for ToolTips
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "GameLib"
require "FriendshipLib"
require "ChallengesLib"

local ToolTips = {}

local kItemTooltipWindowWidth = 300
local kstrTab = "    "
local kUIBody = "ff39b5d4"
local kUITeal = "ff53aa7f"
local kUIRed = "ffda2a00" -- "ffab472f" Sat +50
local kUIGreen = "ff42da00" -- "ff55ab2f" Sat +50
local kUIYellow = kUIBody
local kUILowDurability = "yellow"
local kUIHugeFontSize = "CRB_HeaderSmall"

local karSimpleDispositionUnitTypes =
{
	["Simple"]			= true,
	["Chest"]			= true,
	["Door"]			= true,
	["Collectible"]		= true,
	["Platform"]		= true,
	["Mailbox"]			= true,
	["BindPoint"]		= true,
}

local karNPCDispositionUnitTypes =
{
	["NonPlayer"]			= true,
	["Destructible"]		= true,
	["Vehicle"]				= true,
	["Corpse"]				= true,
	["Mount"]				= true,
	["Taxi"]				= true,
	["DestructibleDoor"]	= true,
	["Turret"]				= true,
	["Pet"]					= true,
	["Esper Pet"]			= true,
	["Scanner"]				= true,
	["StructuredPlug"]		= true,
}

local ktMicrochipTypeNames =
{
	[Item.CodeEnumMicrochipType.PowerSource] 	= Apollo.GetString("CRB_Crafting_Circuit_Power_Core"),
	[Item.CodeEnumMicrochipType.Stat] 			= Apollo.GetString("CRB_Crafting_Circuit_Stat"),
	[Item.CodeEnumMicrochipType.PowerUp] 		= Apollo.GetString("CRB_Crafting_Circuit_Power_Up"),
	[Item.CodeEnumMicrochipType.Special] 		= Apollo.GetString("CRB_Crafting_Circuit_Special"),
	[Item.CodeEnumMicrochipType.Set]			= Apollo.GetString("CRB_Crafting_Circuit_Set"),
	[Item.CodeEnumMicrochipType.Omni] 			= Apollo.GetString("CRB_Crafting_Circuit_Omni"),
	[Item.CodeEnumMicrochipType.Capacitor] 		= Apollo.GetString("CRB_Crafting_Circuit_Capacitor"),
	[Item.CodeEnumMicrochipType.Resistor] 		= Apollo.GetString("CRB_Crafting_Circuit_Resistor"),
	[Item.CodeEnumMicrochipType.Inductor] 		= Apollo.GetString("CRB_Crafting_Circuit_Inductor")
}

local karClassToString =
{
	[GameLib.CodeEnumClass.Warrior]       	= Apollo.GetString("ClassWarrior"),
	[GameLib.CodeEnumClass.Engineer]      	= Apollo.GetString("ClassEngineer"),
	[GameLib.CodeEnumClass.Esper]         	= Apollo.GetString("ClassESPER"),
	[GameLib.CodeEnumClass.Medic]         	= Apollo.GetString("ClassMedic"),
	[GameLib.CodeEnumClass.Stalker]       	= Apollo.GetString("ClassStalker"),
	[GameLib.CodeEnumClass.Spellslinger]    = Apollo.GetString("ClassSpellslinger"),
}

local ktClassToIcon =
{
	[GameLib.CodeEnumClass.Medic]       	= "Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Esper]       	= "Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Warrior]     	= "Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Stalker]     	= "Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Engineer]    	= "Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Spellslinger]  	= "Icon_Windows_UI_CRB_Spellslinger",
}

local ktPathToString =
{
	[PlayerPathLib.PlayerPathType_Soldier]    = Apollo.GetString("PlayerPathSoldier"),
	[PlayerPathLib.PlayerPathType_Settler]    = Apollo.GetString("PlayerPathSettler"),
	[PlayerPathLib.PlayerPathType_Scientist]  = Apollo.GetString("PlayerPathExplorer"),
	[PlayerPathLib.PlayerPathType_Explorer]   = Apollo.GetString("PlayerPathScientist"),
}

local ktPathToIcon =
{
	[PlayerPathLib.PlayerPathType_Soldier]    = "Icon_Windows_UI_CRB_Soldier",
	[PlayerPathLib.PlayerPathType_Settler]    = "Icon_Windows_UI_CRB_Colonist",
	[PlayerPathLib.PlayerPathType_Scientist]  = "Icon_Windows_UI_CRB_Scientist",
	[PlayerPathLib.PlayerPathType_Explorer]   = "Icon_Windows_UI_CRB_Explorer",
}

local karFactionToString =
{
	[Unit.CodeEnumFaction.ExilesPlayer]     = Apollo.GetString("CRB_Exile"),
	[Unit.CodeEnumFaction.DominionPlayer]   = Apollo.GetString("CRB_Dominion"),
}

local karDispositionColors =
{
	[Unit.CodeEnumDisposition.Neutral]  = ApolloColor.new("DispositionNeutral"),
	[Unit.CodeEnumDisposition.Hostile]  = ApolloColor.new("DispositionHostile"),
	[Unit.CodeEnumDisposition.Friendly] = ApolloColor.new("DispositionFriendly"),
}

local karDispositionColorStrings =
{
	[Unit.CodeEnumDisposition.Neutral]  = "DispositionNeutral",
	[Unit.CodeEnumDisposition.Hostile]  = "DispositionHostile",
	[Unit.CodeEnumDisposition.Friendly] = "DispositionFriendly",
}

local karDispositionFrameSprites =
{
	[Unit.CodeEnumDisposition.Neutral]  = "sprTooltip_SquareFrame_UnitYellow",
	[Unit.CodeEnumDisposition.Hostile]  = "sprTooltip_SquareFrame_UnitRed",
	[Unit.CodeEnumDisposition.Friendly] = "sprTooltip_SquareFrame_UnitGreen",
}

local karRaceToString =
{
	[GameLib.CodeEnumRace.Human] 	= Apollo.GetString("RaceHuman"),
	[GameLib.CodeEnumRace.Granok] 	= Apollo.GetString("RaceGranok"),
	[GameLib.CodeEnumRace.Aurin] 	= Apollo.GetString("RaceAurin"),
	[GameLib.CodeEnumRace.Draken] 	= Apollo.GetString("RaceDraken"),
	[GameLib.CodeEnumRace.Mechari] 	= Apollo.GetString("RaceMechari"),
	[GameLib.CodeEnumRace.Chua] 	= Apollo.GetString("RaceChua"),
	[GameLib.CodeEnumRace.Mordesh] 	= Apollo.GetString("CRB_Mordesh"),
}

local karConInfo =
{
	{-4, ApolloColor.new("ConTrivial"), 	Apollo.GetString("TargetFrame_Trivial"), 	Apollo.GetString("Tooltips_None"), 		"ff7d7d7d"},
	{-3, ApolloColor.new("ConInferior"), 	Apollo.GetString("TargetFrame_Inferior"), 	Apollo.GetString("Tooltips_Minimal"), 	"ff01ff07"},
	{-2, ApolloColor.new("ConMinor"), 		Apollo.GetString("TargetFrame_Minor"), 		Apollo.GetString("Tooltips_Minor"), 	"ff01fcff"},
	{-1, ApolloColor.new("ConEasy"), 		Apollo.GetString("TargetFrame_Easy"), 		Apollo.GetString("Tooltips_Low"), 		"ff597cff"},
	{ 0, ApolloColor.new("ConAverage"), 	Apollo.GetString("TargetFrame_Average"), 	Apollo.GetString("Tooltips_Normal"), 	"ffffffff"},
	{ 1, ApolloColor.new("ConModerate"), 	Apollo.GetString("TargetFrame_Moderate"), 	Apollo.GetString("Tooltips_Improved"), 	"ffffff00"},
	{ 2, ApolloColor.new("ConTough"), 		Apollo.GetString("TargetFrame_Tough"), 		Apollo.GetString("Tooltips_High"), 		"ffff8000"},
	{ 3, ApolloColor.new("ConHard"), 		Apollo.GetString("TargetFrame_Hard"), 		Apollo.GetString("Tooltips_Major"), 	"ffff0000"},
	{ 4, ApolloColor.new("ConImpossible"), 	Apollo.GetString("TargetFrame_Impossible"), Apollo.GetString("Tooltips_Superior"),	"ffff00ff"}
}

local ktRankDescriptions =
{
	[Unit.CodeEnumRank.Fodder] 		= 	Apollo.GetString("TargetFrame_Fodder"),
	[Unit.CodeEnumRank.Minion] 		= 	Apollo.GetString("TargetFrame_Minion"),
	[Unit.CodeEnumRank.Standard]	= 	Apollo.GetString("TargetFrame_Grunt"),
	[Unit.CodeEnumRank.Champion] 	=	Apollo.GetString("TargetFrame_Challenger"),
	[Unit.CodeEnumRank.Superior] 	=  	Apollo.GetString("TargetFrame_Superior"),
	[Unit.CodeEnumRank.Elite] 		= 	Apollo.GetString("TargetFrame_Prime"),
}

local ktRewardToIcon =
{
	["Quest"] 			= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_ActiveQuest",
	["Challenge"] 		= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_Challenge",
	["Explorer"] 		= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathExp",
	["Scientist"] 		= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSci",
	["Soldier"] 		= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSol",
	["Settler"] 		= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSet",
	["PublicEvent"] 	= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PublicEvent",
	["Rival"] 			= "ClientSprites:Icon_Windows_UI_CRB_Rival",
	["Friend"] 			= "ClientSprites:Icon_Windows_UI_CRB_Friend",
	["ScientistSpell"]	= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSciSpell"
}

local ktRewardToString =
{
	["Quest"] 			= Apollo.GetString("Tooltips_Quest"),
	["Challenge"] 		= Apollo.GetString("Tooltips_Challenge"),
	["Explorer"] 		= Apollo.GetString("ZoneMap_ExplorerMission"),
	["Scientist"] 		= Apollo.GetString("ZoneMap_ScientistMission"),
	["Soldier"] 		= Apollo.GetString("ZoneMap_SoldierMission"),
	["Settler"] 		= Apollo.GetString("ZoneMap_SettlerMission"),
	["PublicEvent"] 	= Apollo.GetString("ZoneMap_PublicEvent"),
	["Rival"] 			= Apollo.GetString("Tooltips_Rival"),
	["Friend"] 			= Apollo.GetString("Tooltips_Friend"),
	["ScientistSpell"]	= Apollo.GetString("PlayerPathScientist")
}

local karSigilTypeToIcon =
{
	[Item.CodeEnumSigilType.Air] 				= "ClientSprites:Icon_Windows_UI_CRB_Tooltip_Air",
	[Item.CodeEnumSigilType.Water] 				= "ClientSprites:Icon_Windows_UI_CRB_Tooltip_Water",
	[Item.CodeEnumSigilType.Earth] 				= "ClientSprites:Icon_Windows_UI_CRB_Tooltip_Earth",
	[Item.CodeEnumSigilType.Fire] 				= "ClientSprites:Icon_Windows_UI_CRB_Tooltip_Fire",
	[Item.CodeEnumSigilType.Logic] 				= "ClientSprites:Icon_Windows_UI_CRB_Tooltip_Logic",
	[Item.CodeEnumSigilType.Life] 				= "ClientSprites:Icon_Windows_UI_CRB_Tooltip_Life",
	[Item.CodeEnumSigilType.Omni] 				= "ClientSprites:Icon_Windows_UI_CRB_Tooltip_Omni",
	[Item.CodeEnumSigilType.Fusion] 			= "ClientSprites:Icon_Windows_UI_CRB_Tooltip_Fusion",
}

local karSigilTypeToString =
{
	[Item.CodeEnumSigilType.Air] 				= Apollo.GetString("CRB_Air"),
	[Item.CodeEnumSigilType.Water] 				= Apollo.GetString("CRB_Water"),
	[Item.CodeEnumSigilType.Earth] 				= Apollo.GetString("CRB_Earth"),
	[Item.CodeEnumSigilType.Fire] 				= Apollo.GetString("CRB_Fire"),
	[Item.CodeEnumSigilType.Logic] 				= Apollo.GetString("CRB_Logic"),
	[Item.CodeEnumSigilType.Life] 				= Apollo.GetString("CRB_Life"),
	[Item.CodeEnumSigilType.Omni] 				= Apollo.GetString("CRB_Omni"),
	[Item.CodeEnumSigilType.Fusion] 			= Apollo.GetString("CRB_Fusion"),
}

local ktAttributeToText =
{
	[Unit.CodeEnumProperties.Dexterity] 					= Apollo.GetString("CRB_Finesse"),
	[Unit.CodeEnumProperties.Technology] 					= Apollo.GetString("CRB_Tech_Attribute"),
	[Unit.CodeEnumProperties.Magic] 						= Apollo.GetString("CRB_Moxie"),
	[Unit.CodeEnumProperties.Wisdom] 						= Apollo.GetString("UnitPropertyInsight"),
	[Unit.CodeEnumProperties.Stamina] 						= Apollo.GetString("CRB_Grit"),
	[Unit.CodeEnumProperties.Strength] 						= Apollo.GetString("CRB_Brutality"),

	[Unit.CodeEnumProperties.Armor] 						= Apollo.GetString("CRB_Armor") ,
	[Unit.CodeEnumProperties.ShieldCapacityMax] 			= Apollo.GetString("CBCrafting_Shields"),

	[Unit.CodeEnumProperties.AssaultPower] 					= Apollo.GetString("CRB_Assault_Power"),
	[Unit.CodeEnumProperties.SupportPower] 					= Apollo.GetString("CRB_Support_Power"),
	[Unit.CodeEnumProperties.Rating_AvoidReduce] 			= Apollo.GetString("CRB_Strikethrough_Rating"),
	[Unit.CodeEnumProperties.Rating_CritChanceIncrease] 	= Apollo.GetString("CRB_Critical_Chance"),
	[Unit.CodeEnumProperties.RatingCritSeverityIncrease] 	= Apollo.GetString("CRB_Critical_Severity"),
	[Unit.CodeEnumProperties.Rating_AvoidIncrease] 			= Apollo.GetString("CRB_Deflect_Rating"),
	[Unit.CodeEnumProperties.Rating_CritChanceDecrease] 	= Apollo.GetString("CRB_Deflect_Critical_Hit_Rating"),
	[Unit.CodeEnumProperties.ManaPerFiveSeconds] 			= Apollo.GetString("CRB_Attribute_Recovery_Rating"),
	[Unit.CodeEnumProperties.HealthRegenMultiplier] 		= Apollo.GetString("CRB_Health_Regen_Factor"),
	[Unit.CodeEnumProperties.BaseHealth] 					= Apollo.GetString("CRB_Health_Max"),

	[Unit.CodeEnumProperties.ResistTech] 					= Apollo.GetString("Tooltip_ResistTech"),
	[Unit.CodeEnumProperties.ResistMagic]					= Apollo.GetString("Tooltip_ResistMagic"),
	[Unit.CodeEnumProperties.ResistPhysical]				= Apollo.GetString("Tooltip_ResistPhysical"),

	[Unit.CodeEnumProperties.PvPOffensiveRating] 			= Apollo.GetString("Tooltip_PvPOffense"),
	[Unit.CodeEnumProperties.PvPDefensiveRating]			= Apollo.GetString("Tooltip_PvPDefense"),
}

-- TODO REFACTOR, we can combine all these item quality tables into one
local karEvalColors =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "ItemQuality_Inferior",
	[Item.CodeEnumItemQuality.Average] 			= "ItemQuality_Average",
	[Item.CodeEnumItemQuality.Good] 			= "ItemQuality_Good",
	[Item.CodeEnumItemQuality.Excellent] 		= "ItemQuality_Excellent",
	[Item.CodeEnumItemQuality.Superb] 			= "ItemQuality_Superb",
	[Item.CodeEnumItemQuality.Legendary] 		= "ItemQuality_Legendary",
	[Item.CodeEnumItemQuality.Artifact]		 	= "ItemQuality_Artifact",
}

local karEvalSprites =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "sprTT_HeaderDarkGrey",
	[Item.CodeEnumItemQuality.Average] 			= "sprTT_HeaderWhite",
	[Item.CodeEnumItemQuality.Good] 			= "sprTT_HeaderGreen",
	[Item.CodeEnumItemQuality.Excellent] 		= "sprTT_HeaderBlue",
	[Item.CodeEnumItemQuality.Superb] 			= "sprTT_HeaderPurple",
	[Item.CodeEnumItemQuality.Legendary] 		= "sprTT_HeaderOrange",
	[Item.CodeEnumItemQuality.Artifact]		 	= "sprTT_HeaderLightPurple",
}

local karEvalInsetSprites =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "sprTT_HeaderInsetDarkGrey",
	[Item.CodeEnumItemQuality.Average] 			= "sprTT_HeaderInsetWhite",
	[Item.CodeEnumItemQuality.Good] 			= "sprTT_HeaderInsetGreen",
	[Item.CodeEnumItemQuality.Excellent] 		= "sprTT_HeaderInsetBlue",
	[Item.CodeEnumItemQuality.Superb] 			= "sprTT_HeaderInsetPurple",
	[Item.CodeEnumItemQuality.Legendary] 		= "sprTT_HeaderOrange",
	[Item.CodeEnumItemQuality.Artifact]		 	= "sprTT_HeaderInsetLightPurple"
}

local karEvalStrings =
{
	[Item.CodeEnumItemQuality.Inferior] 		= Apollo.GetString("CRB_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= Apollo.GetString("CRB_Average"),
	[Item.CodeEnumItemQuality.Good] 			= Apollo.GetString("CRB_Good"),
	[Item.CodeEnumItemQuality.Excellent] 		= Apollo.GetString("CRB_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= Apollo.GetString("CRB_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 		= Apollo.GetString("CRB_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]		 	= Apollo.GetString("CRB_Artifact")
}

local karItemQualityToHeaderBG =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "CRB_Tooltips:sprTooltip_Header_Silver",
	[Item.CodeEnumItemQuality.Average] 			= "CRB_Tooltips:sprTooltip_Header_White",
	[Item.CodeEnumItemQuality.Good] 			= "CRB_Tooltips:sprTooltip_Header_Green",
	[Item.CodeEnumItemQuality.Excellent] 		= "CRB_Tooltips:sprTooltip_Header_Blue",
	[Item.CodeEnumItemQuality.Superb] 			= "CRB_Tooltips:sprTooltip_Header_Purple",
	[Item.CodeEnumItemQuality.Legendary] 		= "CRB_Tooltips:sprTooltip_Header_Orange",
	[Item.CodeEnumItemQuality.Artifact]		 	= "CRB_Tooltips:sprTooltip_Header_Pink",
}

local karItemQualityToHeaderBar =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "CRB_Tooltips:sprTooltip_RarityBar_Silver",
	[Item.CodeEnumItemQuality.Average] 			= "CRB_Tooltips:sprTooltip_RarityBar_White",
	[Item.CodeEnumItemQuality.Good] 			= "CRB_Tooltips:sprTooltip_RarityBar_Green",
	[Item.CodeEnumItemQuality.Excellent] 		= "CRB_Tooltips:sprTooltip_RarityBar_Blue",
	[Item.CodeEnumItemQuality.Superb] 			= "CRB_Tooltips:sprTooltip_RarityBar_Purple",
	[Item.CodeEnumItemQuality.Legendary] 		= "CRB_Tooltips:sprTooltip_RarityBar_Orange",
	[Item.CodeEnumItemQuality.Artifact]		 	= "CRB_Tooltips:sprTooltip_RarityBar_Pink",
}

local karItemQualityToBorderFrameBG =
{
	[Item.CodeEnumItemQuality.Inferior] 		= "CRB_Tooltips:sprTooltip_SquareFrame_Silver",
	[Item.CodeEnumItemQuality.Average] 			= "CRB_Tooltips:sprTooltip_SquareFrame_White",
	[Item.CodeEnumItemQuality.Good] 			= "CRB_Tooltips:sprTooltip_SquareFrame_Green",
	[Item.CodeEnumItemQuality.Excellent] 		= "CRB_Tooltips:sprTooltip_SquareFrame_Blue",
	[Item.CodeEnumItemQuality.Superb] 			= "CRB_Tooltips:sprTooltip_SquareFrame_Purple",
	[Item.CodeEnumItemQuality.Legendary] 		= "CRB_Tooltips:sprTooltip_SquareFrame_Orange",
	[Item.CodeEnumItemQuality.Artifact]		 	= "CRB_Tooltips:sprTooltip_SquareFrame_Pink",
}

local kcrGroupTextColor					= ApolloColor.new("crayBlizzardBlue")
local kcrFlaggedFriendlyTextColor 		= karDispositionColors[Unit.CodeEnumDisposition.Friendly]
local kcrDefaultUnflaggedAllyTextColor 	= karDispositionColors[Unit.CodeEnumDisposition.Friendly]
local kcrAggressiveEnemyTextColor 		= karDispositionColors[Unit.CodeEnumDisposition.Neutral]
local kcrNeutralEnemyTextColor 			= ApolloColor.new("crayDenim")

--[[
local karEvalType =
{
    Apollo.GetString("CRB_Equal"),
    Apollo.GetString("CRB_Greater"),
    Apollo.GetString("CRB_Greater_Or_Equal"),
    Apollo.GetString("CRB_Less"),
    Apollo.GetString("CRB_Less_Or_Equal"),
    Apollo.GetString("CRB_Equal"),
    Apollo.GetString("CRB_Greater"),
    Apollo.GetString("CRB_Greater_Or_Equal"),
    Apollo.GetString("CRB_Less"),
    Apollo.GetString("CRB_Less_Or_Equal")
}
]]--

--local kstrCast = Apollo.GetString("CRB_Cast_")
--local kstrTier 			= Apollo.GetString("CRB_Tier_")
--local kstrRequires 		= Apollo.GetString("CRB_Requires_")
--local kstrTarget 		= Apollo.GetString("CRB_Target_")
--local kstrCastTime 		= Apollo.GetString("CRB_Cast_Time_")
--local kstrChannelTime 	= Apollo.GetString("CRB_Channel_Time_")
--local kstrCooldown 		= Apollo.GetString("CRB_Cooldown_")
--local kstrInstant 		= Apollo.GetString("CRB_Instant")
--local kstrCost 			= Apollo.GetString("CRB_Cost_Sp")
--local kstrHP 			= Apollo.GetString("CRB_HP")
--local kstrUnique 		= Apollo.GetString("CRB_Unique")
--local kstrArmor 		= Apollo.GetString("CRB_Armor")
--local kstrBag 			= Apollo.GetString("CRB_Bag")
--local kstrConsumable 	= Apollo.GetString("CRB_Consumable")
--local kstrQuestItem 	= Apollo.GetString("CRB_Quest_Item")
--local kstrJunk 			= Apollo.GetString("CRB_Junk")

local tVitals = {}

local knWndHeightBuffer

function ToolTips:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function ToolTips:Init()
	Apollo.RegisterAddon(self)
end

function ToolTips:OnLoad()
    self.xmlDoc = XmlDoc.CreateFromFile("TooltipsForms.xml")
    self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ToolTips:OnDocumentReady()
    if self.xmlDoc == nil then
        return
    end

	tVitals = Unit.GetVitalTable()

	Apollo.RegisterEventHandler("PlayerChanged", "OnUpdateVitals", self)
	Apollo.RegisterEventHandler("MatchEntered", "OnUpdateVitals", self)
	Apollo.RegisterEventHandler("MouseOverUnitChanged", "OnMouseOverUnitChanged", self)

	local wndTooltip = Apollo.LoadForm(self.xmlDoc, "ItemTooltip_Base", nil, self)
	local wndTooltipItem = wndTooltip:FindChild("Items")

	knWndHeightBuffer = wndTooltip:GetHeight() - wndTooltipItem:GetHeight()

	wndTooltip:Destroy()
	wndTooltipItem:Destroy()

	self:CreateCallNames()

	self.wndContainer = Apollo.LoadForm("TooltipsForms.xml", "WorldTooltipContainer", nil, self)
	GameLib.SetWorldTooltipContainer(self.wndContainer)
end

function ToolTips:UnitTooltipGen(wndContainer, unitSource, strProp)
	local wndTooltipForm = nil
	local bSkipFormatting = false -- used to identify when we switch to item tooltips (aka pinata loot)
	local bNoDisposition = false -- used to replace dispostion assets when they're not needed
	local bHideFormSecondary = true
	
	if not unitSource and strProp == "" then
		wndContainer:SetTooltipForm(nil)
		wndContainer:SetTooltipFormSecondary(nil)
		return
	elseif strProp ~= "" then
		if not self.wndPropTooltip or not self.wndPropTooltip:IsValid() then
			self.wndPropTooltip = wndContainer:LoadTooltipForm("ui\\Tooltips\\TooltipsForms.xml", "PropTooltip_Base", self)
		end
		self.wndPropTooltip:FindChild("NameString"):SetText(strProp)

		wndContainer:SetTooltipForm(self.wndPropTooltip)
		wndContainer:SetTooltipFormSecondary(nil)
		return
	end

	if not self.wndUnitTooltip or not self.wndUnitTooltip:IsValid() then
		self.wndUnitTooltip = wndContainer:LoadTooltipForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Base", self)
	end

	local wndTopDataBlock 			= self.wndUnitTooltip:FindChild("TopDataBlock")
	local wndMiddleDataBlock 		= self.wndUnitTooltip:FindChild("MiddleDataBlock") -- THIS GETS USED FOR A LOT!!
	local wndBottomDataBlock 		= self.wndUnitTooltip:FindChild("BottomDataBlock")
	local wndTopRight				= wndTopDataBlock:FindChild("RightSide")
	local wndMiddleDataBlockContent = wndMiddleDataBlock:FindChild("MiddleDataBlockContent")
	local wndPathIcon 				= wndTopRight:FindChild("PathIcon")
	local wndClassIcon 				= wndTopRight:FindChild("ClassIcon")
	local wndClassBack 				= wndTopRight:FindChild("ClassBack")
	local wndPathBack 				= wndTopRight:FindChild("PathBack")
	local wndLevelBack 				= wndTopRight:FindChild("LevelBack")
	local wndXpAwardString 			= wndBottomDataBlock:FindChild("XpAwardString")
	local wndBreakdownString 		= wndBottomDataBlock:FindChild("BreakdownString")
	local wndDispositionFrame 		= self.wndUnitTooltip:FindChild("DispositionArtFrame")
	local wndNameString 			= wndTopDataBlock:FindChild("NameString")
	local wndLevelString 			= self.wndUnitTooltip:FindChild("LevelString")
	local wndAffiliationString 		= self.wndUnitTooltip:FindChild("AffiliationString")

	local unitPlayer = GameLib.GetPlayerUnit()
	local eDisposition = unitSource:GetDispositionTo(unitPlayer)

	local fullWndLeft, fullWndTop, fullWndRight, fullWndBottom = self.wndUnitTooltip:GetAnchorOffsets()
	local topBlockLeft, topBlockTop, topBlockRight, topBlockBottom = self.wndUnitTooltip:FindChild("TopDataBlock"):GetAnchorOffsets()

	-- Basics
	wndLevelString:SetText(unitSource:GetLevel())
	wndNameString:SetText(string.format("<P Font=\"CRB_HeaderSmall\" TextColor=\"%s\">%s</P>", karDispositionColorStrings[eDisposition], unitSource:GetName()))
	wndDispositionFrame:SetSprite(karDispositionFrameSprites[eDisposition] or "")

	-- Unit to player affiliation
	local strAffiliationName = unitSource:GetAffiliationName() or ""
	wndAffiliationString:SetTextRaw(strAffiliationName)
	wndAffiliationString:Show(strAffiliationName ~= "")
	wndAffiliationString:SetTextColor(karDispositionColors[eDisposition])

	-- Reward info
	wndMiddleDataBlockContent:DestroyChildren()
	for idx, tRewardInfo in pairs(unitSource:GetRewardInfo() or {}) do
		local strRewardType = tRewardInfo.strType
		local bCanAddReward = true

		-- Only show active challenge rewards
		if strRewardType == "Challenge" then
			bCanAddReward = false
			for index, clgCurr in pairs(ChallengesLib.GetActiveChallengeList()) do
				if tRewardInfo.idChallenge == clgCurr:GetId() and clgCurr:IsActivated() and not clgCurr:IsInCooldown() and not clgCurr:ShouldCollectReward() then
					bCanAddReward = true
					break
				end
			end
		end

		if bCanAddReward and ktRewardToIcon[strRewardType] and ktRewardToString[strRewardType] then
			if strRewardType == "PublicEvent" then
				tRewardInfo.strTitle = tRewardInfo.peoObjective:GetEvent():GetName() or ""
			elseif strRewardType == "Soldier" or strRewardType == "Explorer" or strRewardType == "Settler" then
				tRewardInfo.strTitle = tRewardInfo.pmMission and tRewardInfo.pmMission:GetName() or ""
			elseif strRewardType == "Scientist" then
				if tRewardInfo.pmMission then
					if tRewardInfo.pmMission:GetMissionState() >= PathMission.PathMissionState_Unlocked then
						tRewardInfo.strTitle = tRewardInfo.pmMission:GetName()
					else
						tRewardInfo.strTitle = Apollo.GetString("TargetFrame_UnknownReward")
					end
				end
			end

			if tRewardInfo.strTitle and tRewardInfo.strTitle ~= "" then
				local wndReward = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Reward", wndMiddleDataBlockContent, self)
				wndReward:FindChild("Icon"):SetSprite(ktRewardToIcon[strRewardType])
				wndReward:FindChild("Label"):SetText(String_GetWeaselString(Apollo.GetString("Tooltip_TitleReward"), tRewardInfo.strTitle, ktRewardToString[strRewardType]))
				
				-- Adjust height to fit text
				wndReward:FindChild("Label"):SetHeightToContentHeight()
				if wndReward:FindChild("Label"):GetHeight() > wndReward:GetHeight() then
					local rewardWndLeft, rewardWndTop, rewardWndRight, rewardWndBottom = wndReward:GetAnchorOffsets()
					wndReward:SetAnchorOffsets(rewardWndLeft, rewardWndTop, rewardWndRight, wndReward:FindChild("Label"):GetHeight())
				end
			end
		end
	end

	local strUnitType = unitSource:GetType()
	if strUnitType == "Player" then

		-- Player
		local tSourceStats = unitSource:GetBasicStats()
		local ePathType = unitSource:GetPlayerPathType()
		local eClassType = unitSource:GetClassId()
		local bIsPvpFlagged = unitSource:IsPvpFlagged()

		wndPathIcon:SetSprite(ktPathToIcon[ePathType])
		wndClassIcon:SetSprite(ktClassToIcon[eClassType])

		-- Player specific affiliation override
		local strPlayerAffiliationName = unitSource:GetGuildName()
		if strPlayerAffiliationName then
			wndAffiliationString:SetTextRaw(String_GetWeaselString(Apollo.GetString("Nameplates_GuildDisplay"), strPlayerAffiliationName))
			wndAffiliationString:Show(true)
		end

		-- Player specific disposition color override
		local crColorToUse = karDispositionColors[eDisposition]
		if eDisposition == Unit.CodeEnumDisposition.Friendly then
			if unitSource:IsPvpFlagged() then
				crColorToUse = kcrFlaggedFriendlyTextColor
			elseif unitSource:IsInYourGroup() then
				crColorToUse = kcrGroupTextColor
			else
				crColorToUse = kcrDefaultUnflaggedAllyTextColor
			end
		else
			local bIsUnitFlagged = unitSource:IsPvpFlagged()
			local bAmIFlagged = GameLib.IsPvpFlagged()
			if not bAmIFlagged and not bIsUnitFlagged then
				crColorToUse = kcrNeutralEnemyTextColor
			elseif bAmIFlagged ~= bIsUnitFlagged then
				crColorToUse = kcrAggressiveEnemyTextColor
			end
		end
		wndNameString:SetTextColor(crColorToUse)
		wndAffiliationString:SetTextColor(crColorToUse)

		-- Determine if Exile Human or Cassian
		local strRaceString = ""
		local nRaceID = unitSource:GetRaceId()
		local nFactionID = unitSource:GetFaction()
		if nRaceID == GameLib.CodeEnumRace.Human then
			if nFactionID == Unit.CodeEnumFaction.ExilesPlayer then
				strRaceString = Apollo.GetString("CRB_ExileHuman")
			elseif nFactionID == Unit.CodeEnumFaction.DominionPlayer then
				strRaceString = Apollo.GetString("CRB_Cassian")
			end
		else
			strRaceString = karRaceToString[nRaceID]
		end

		local strBreakdown = String_GetWeaselString(Apollo.GetString("Tooltip_CharacterDescription"), tSourceStats.nLevel, strRaceString)
		if tSourceStats.nEffectiveLevel ~= 0 and unitSource:IsMentoring() then -- GOTCHA: Intentionally we don't care about IsRallied()
			strBreakdown = String_GetWeaselString(Apollo.GetString("Tooltips_MentoringAppend"), strBreakdown, tSourceStats.nEffectiveLevel)
		end
		if bIsPvpFlagged then
			strBreakdown = String_GetWeaselString(Apollo.GetString("Tooltips_PvpFlagged"), strBreakdown)
		end
		wndBreakdownString:SetText(strBreakdown)

		-- Friend or Rival
		if unitSource:IsFriend() then
			local wndReward = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Reward", wndMiddleDataBlockContent, self)
			wndReward:FindChild("Icon"):SetSprite(ktRewardToIcon["Friend"])
			wndReward:FindChild("Label"):SetText(ktRewardToString["Friend"])
			wndMiddleDataBlockContent:Show(true)
		end

		if unitSource:IsRival() then
			local wndReward = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Reward", wndMiddleDataBlockContent, self)
			wndReward:FindChild("Icon"):SetSprite(ktRewardToIcon["Rival"])
			wndReward:FindChild("Label"):SetText(ktRewardToString["Rival"])
			wndMiddleDataBlockContent:Show(true)
		end

		wndBottomDataBlock:Show(true)
		wndPathIcon:Show(true)
		wndClassIcon:Show(true)
		wndLevelString:Show(true)
		wndXpAwardString:Show(false)
		wndBreakdownString:Show(true)

	elseif karNPCDispositionUnitTypes[strUnitType] then
		-- NPC

		local nCon = self:HelperCalculateConValue(unitSource)
		if nCon == 1 then
			wndXpAwardString:SetAML("")
		else
			local strXPFinal = String_GetWeaselString(Apollo.GetString("Tooltips_XPAwardValue"), Apollo.GetString("Tooltips_XpAward"), karConInfo[nCon][4])
			wndXpAwardString:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextHoloBody\" Align=\"Right\">%s</P>", strXPFinal))
		end
		wndBreakdownString:SetText(ktRankDescriptions[unitSource:GetRank()] or "")

		-- Settler improvement
		if unitSource:IsSettlerImprovement() then
			if unitSource:IsSettlerReward() then
				local strSettlerRewardName = String_GetWeaselString(Apollo.GetString("Tooltips_SettlerReward"), unitSource:GetSettlerRewardName(), Apollo.GetString("CRB_Settler_Reward"))
				local wndInfo = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Info", wndMiddleDataBlockContent, self)
				wndInfo:FindChild("Label"):SetText(strSettlerRewardName)
			else
				local tSettlerImprovementInfo = unitSource:GetSettlerImprovementInfo()

				for idx, strOwnerName in pairs(tSettlerImprovementInfo.arOwnerNames) do
					local wndInfo = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Info", wndMiddleDataBlockContent, self)
					wndInfo:FindChild("Label"):SetText(Apollo.GetString("Tooltips_GetSettlerDepot")..strOwnerName)
				end

				if not tSettlerImprovementInfo.bIsInfiniteDuration then
					local strSettlerTimeRemaining = string.format(Apollo.GetString("CRB_Remaining_Time_Format"), tSettlerImprovementInfo.nRemainingTime)
					local wndInfo = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Info", wndMiddleDataBlockContent, self)
					wndInfo:FindChild("Label"):SetText(strSettlerTimeRemaining)
				end

				for idx, tTier in pairs(tSettlerImprovementInfo.arTiers) do
					local wndInfo = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Info", wndMiddleDataBlockContent, self)
					wndInfo:FindChild("Label"):SetText(String_GetWeaselString(Apollo.GetString("Tooltips_SettlerTier"), tTier.nTier, tTier.strName))
				end
			end
		end

		-- Friendly Warplot structure
		if unitSource:IsFriendlyWarplotStructure() then
			local strCurrentTier = String_GetWeaselString(Apollo.GetString("CRB_WarplotPlugTier"), unitSource:GetCurrentWarplotTier())
			local wndCurrentTier = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Info", wndMiddleDataBlockContent, self)
			wndCurrentTier:FindChild("Label"):SetText(strCurrentTier)
			if unitSource:CanUpgradeWarplotStructure() then
				local strCurrentCost = String_GetWeaselString(Apollo.GetString("CRB_WarplotPlugUpgradeCost"), unitSource:GetCurrentWarplotUpgradeCost())
				local wndCurrentCost = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Info", wndMiddleDataBlockContent, self)
				wndCurrentCost:FindChild("Label"):SetText(strCurrentCost)
			end
		end

		wndBottomDataBlock:Show(true)
		wndPathIcon:Show(false)
		wndClassIcon:Show(false)
		wndLevelString:Show(true)
		wndXpAwardString:Show(eDisposition == Unit.CodeEnumDisposition.Hostile or eDisposition == Unit.CodeEnumDisposition.Neutral)
		wndBreakdownString:Show(true)

	elseif karSimpleDispositionUnitTypes[strUnitType] then

		-- Simple
		bNoDisposition = true

		wndBottomDataBlock:Show(false)
		wndPathIcon:Show(false)
		wndClassIcon:Show(false)
		wndLevelString:Show(true)
		wndXpAwardString:Show(false)
		wndBreakdownString:Show(false)

	elseif strUnitType == "InstancePortal" then
		-- Instance Portal
		bNoDisposition = true

		local tLevelRange = unitSource:GetInstancePortalLevelRange()
		if tLevelRange and tLevelRange.nMinLevel and tLevelRange.nMaxLevel then
			local strInstancePortalLevelRange = ""
			if tLevelRange.nMinLevel == tLevelRange.nMaxLevel then
				strInstancePortalLevelRange = string.format(Apollo.GetString("InstancePortal_RequiredLevel"), tLevelRange.nMaxLevel)
			else
				strInstancePortalLevelRange = string.format(Apollo.GetString("InstancePortal_LevelRange"), tLevelRange.nMinLevel, tLevelRange.nMaxLevel)
			end
			local wndInfo = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Info", wndMiddleDataBlockContent, self)
			wndInfo:FindChild("Label"):SetText(strInstancePortalLevelRange)
		end

		local nPortalCompletionTime = unitSource:GetInstancePortalCompletionTime()
		if nPortalCompletionTime then
			local strInstanceCompletionTime = string.format(Apollo.GetString("InstancePortal_ExpectedCompletionTime"), nPortalCompletionTime)
			local wndInfo = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Info", wndMiddleDataBlockContent, self)
			wndInfo:FindChild("Label"):SetText(strInstanceCompletionTime)
		end

		local nPortalRemainingTime = unitSource:GetInstancePortalRemainingTime()
		if nPortalRemainingTime and nPortalRemainingTime > 0 then
			local strInstancePortalRemainingTime = string.format(Apollo.GetString("CRB_Remaining_Time_Format"), nPortalRemainingTime)
			local wndInfo = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Info", wndMiddleDataBlockContent, self)
			wndInfo:FindChild("Label"):SetText(strInstancePortalRemainingTime)
		end

		wndBottomDataBlock:Show(false)
		wndPathIcon:Show(false)
		wndClassIcon:Show(false)
		wndLevelString:Show(false)
		wndXpAwardString:Show(false)
		wndBreakdownString:Show(false)

	elseif strUnitType == "Harvest" then
		-- Harvestable
		bNoDisposition = true

		local strHarvestRequiredTradeskillName = unitSource:GetHarvestRequiredTradeskillName()
		local wndInfo = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Info", wndMiddleDataBlockContent, self)
		wndInfo:FindChild("Label"):SetText(strHarvestRequiredTradeskillName)

		if strHarvestRequiredTradeskillName then
			wndBreakdownString:SetText(string.format(Apollo.GetString("CRB_Requires_Tradeskill_Tier"), strHarvestRequiredTradeskillName, unitSource:GetHarvestRequiredTradeskillTier()))
		end

		wndBottomDataBlock:Show(true)
		wndPathIcon:Show(false)
		wndClassIcon:Show(false)
		wndLevelString:Show(false)
		wndXpAwardString:Show(false)
		wndBreakdownString:Show(true)

	elseif strUnitType == "PinataLoot" then
		local tLoot = unitSource:GetLoot()
		if tLoot then
			bNoDisposition = true

			if tLoot.eLootItemType == Unit.CodeEnumLootItemType.StaticItem then
				bHideFormSecondary = false
				local itemEquipped = tLoot.itemLoot:GetEquippedItemForItemType()
				-- Overwrite everything and show itemLoot tooltip instead
				wndTooltipForm = Tooltip.GetItemTooltipForm(self, wndContainer, tLoot.itemLoot, {bPrimary = true, itemCompare = itemEquipped, itemModData = tLoot.itemModData, tGlyphData = tLoot.itemSigilData})
				bSkipFormatting = true
			elseif tLoot.eLootItemType == Unit.CodeEnumLootItemType.Cash then
				local wndCash = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_Cash", wndMiddleDataBlockContent, self)
				wndCash:FindChild("CashWindow"):SetAmount(tLoot.monCurrency, true)

			elseif tLoot.eLootItemType == Unit.CodeEnumLootItemType.VirtualItem then
				local wndLoot = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_PinataLoot", wndMiddleDataBlockContent, self)
				local wndLootLeft, wndLootTop, wndLootRight, wndLootBottom = wndLoot:GetAnchorOffsets()

				wndLoot:FindChild("TextWindow"):SetText(tLoot.tVirtualItem.strFlavor)
				wndLoot:FindChild("TextWindow"):SetHeightToContentHeight()
				wndLoot:SetAnchorOffsets( wndLootLeft, wndLootTop, wndLootRight, math.max(wndLootBottom, wndLoot:FindChild("TextWindow"):GetHeight()))

			elseif tLoot.eLootItemType == Unit.CodeEnumLootItemType.AdventureSpell then
				local wndLoot = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "UnitTooltip_PinataLoot", wndMiddleDataBlockContent, self)
				local wndLootLeft, wndLootTop, wndLootRight, wndLootBottom = wndLoot:GetAnchorOffsets()

				wndLoot:FindChild("TextWindow"):SetText(tLoot.tAbility.strDescription)
				wndLoot:FindChild("TextWindow"):SetHeightToContentHeight()
				wndLoot:SetAnchorOffsets( wndLootLeft, wndLootTop, wndLootRight, math.max(wndLootBottom, wndLoot:FindChild("TextWindow"):GetHeight()))
			end
		end

		wndBottomDataBlock:Show(false)
		wndPathIcon:Show(false)
		wndClassIcon:Show(false)
		wndLevelString:Show(false)
		wndXpAwardString:Show(false)
		wndBreakdownString:Show(false)

	else -- error state, do name only
		bNoDisposition = true

		wndBottomDataBlock:Show(false)
		wndPathIcon:Show(false)
		wndClassIcon:Show(false)
		wndLevelString:Show(true)
		wndXpAwardString:Show(false)
		wndBreakdownString:Show(false)
	end

	-- formatting and resizing --
	if not bSkipFormatting then
		if bNoDisposition then
			wndNameString:SetTextColor(ApolloColor.new("UI_TextHoloBodyHighlight"))
			wndDispositionFrame:SetSprite("sprTooltip_SquareFrame_UnitTeal")
		end

		wndClassBack:Show(wndClassIcon:IsShown())
		wndPathBack:Show(wndPathIcon:IsShown())
		wndLevelBack:Show(wndLevelString:GetText() ~= "")

		-- Right anchor of name
		local lsLeft, lsTop, lsRight, lsBottom = wndNameString:GetAnchorOffsets()
		if wndPathIcon:IsShown() then
			local pathLeft, pathTop, pathRight, pathBottom = wndPathBack:GetAnchorOffsets()
			wndNameString:SetAnchorOffsets(lsLeft, lsTop, pathLeft, lsBottom)
		elseif wndClassIcon:IsShown() then
			local classLeft, classTop, classRight, classBottom = wndClassBack:GetAnchorOffsets()
			wndNameString:SetAnchorOffsets(lsLeft, lsTop, classLeft, lsBottom)
		elseif wndLevelString:IsShown() then
			local levelLeft, levelTop, levelRight, levelBottom = wndLevelBack:GetAnchorOffsets()
			wndNameString:SetAnchorOffsets(lsLeft, lsTop, levelLeft, lsBottom)
		else
			local levelLeft, levelTop, levelRight, levelBottom = wndLevelBack:GetAnchorOffsets()
			wndNameString:SetAnchorOffsets(lsLeft, lsTop, levelRight, lsBottom)
		end

		-- Vertical Height
		local nHeight = 16 -- Space between the bottom of BottomDataBlock and the bottom of the entire window

		local nNameWidth, nNameHeight = wndNameString:SetHeightToContentHeight()
		nNameHeight = math.max(nNameHeight, 32) -- 32 is starting height from XML
		local nTopDataBlockLeft, nTopDataBlockTop, nTopDataBlockRight, nTopDataBlockBottom = wndTopDataBlock:GetAnchorOffsets()
		wndTopDataBlock:SetAnchorOffsets(nTopDataBlockLeft, nTopDataBlockTop, nTopDataBlockRight, nTopDataBlockTop + math.max(32, lsTop + nNameHeight))

		local nTopDataBlockHeight = wndTopDataBlock:GetHeight()
		nHeight = nHeight + nTopDataBlockHeight

		if wndAffiliationString:IsShown() then
			local nLeft, nTop, nRight, nBottom = wndAffiliationString:GetAnchorOffsets()
			local nAffiliationBottom = nTopDataBlockHeight + wndAffiliationString:GetHeight()
			wndAffiliationString:SetAnchorOffsets(nLeft, nTopDataBlockHeight, nRight, nAffiliationBottom)

			local nLeft, nTop, nRight, nBottom = wndMiddleDataBlock:GetAnchorOffsets()
			wndMiddleDataBlock:SetAnchorOffsets(nLeft, nAffiliationBottom, nRight, nAffiliationBottom + wndMiddleDataBlock:GetHeight())

			nHeight = nHeight + wndAffiliationString:GetHeight()
		else
			local nLeft, nTop, nRight, nBottom = wndMiddleDataBlock:GetAnchorOffsets()
			wndMiddleDataBlock:SetAnchorOffsets(nLeft, nTopDataBlockHeight, nRight, nBottom)
		end

		-- Size middle block
		local bShowMiddleBlock = #wndMiddleDataBlockContent:GetChildren() > 0
		wndMiddleDataBlock:Show(bShowMiddleBlock)
		if bShowMiddleBlock then
			local nInnerHeight = wndMiddleDataBlockContent:ArrangeChildrenVert(0)
			local nOuterHeight = nInnerHeight + 8
			nHeight = nHeight + nOuterHeight + 8

			local nLeft, nTop, nRight, nBottom = wndMiddleDataBlockContent:GetAnchorOffsets()
			wndMiddleDataBlockContent:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nInnerHeight)

			local nLeft, nTop, nRight, nBottom = wndMiddleDataBlock:GetAnchorOffsets()
			wndMiddleDataBlock:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nOuterHeight)
		end

		-- Size Tooltip
		if wndXpAwardString:IsShown() or wndBreakdownString:IsShown() then
			nHeight = nHeight + wndBottomDataBlock:GetHeight()
		end

		self.wndUnitTooltip:SetAnchorOffsets(fullWndLeft, fullWndTop, fullWndRight, fullWndTop + nHeight)
	end

	if not wndTooltipForm then
		wndTooltipForm = self.wndUnitTooltip
	end

	self.unitTooltip = unitSource

	wndContainer:SetTooltipForm(wndTooltipForm)
	if bHideFormSecondary then
		wndContainer:SetTooltipFormSecondary(nil)
	end
end

------------------
-- Item Tooltip --
------------------

-- #############################

local function ItemTooltipHeaderHelper(wndParent, tItemInfo, itemSource, wndTooltip, tFlags)
	local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "ItemTooltip_Header", wndParent)
	local wndItemTooltip_HeaderBG = wnd:FindChild("ItemTooltip_HeaderBG")
	wndItemTooltip_HeaderBG:SetSprite(karItemQualityToHeaderBG[tItemInfo.eQuality])
	wndItemTooltip_HeaderBG:Show(not tFlags.bInvisibleFrame)
	wnd:FindChild("ItemTooltip_HeaderBar"):SetSprite(karItemQualityToHeaderBar[tItemInfo.eQuality])

	if tItemInfo.tProfRequirement and not tItemInfo.tProfRequirement.bRequirementMet then
		wnd:FindChild("ItemTooltip_Header_Types"):SetTextColor(kUIRed)
	else
		wnd:FindChild("ItemTooltip_Header_Types"):SetTextColor(karEvalColors[tItemInfo.eQuality])
	end
	wnd:FindChild("ItemTooltip_Header_Types"):SetText(itemSource:GetItemTypeName())

	wnd:FindChild("ItemTooltip_Header_Name"):SetAML("<P Font=\"CRB_HeaderSmall\" TextColor=\""..karEvalColors[tItemInfo.eQuality].."\">"..tItemInfo.strName.."</P>")
	local nWidth, nHeight = wnd:FindChild("ItemTooltip_Header_Name"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wnd:GetAnchorOffsets()
	wnd:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.max(20, nHeight) + 63)
end

local function ItemTooltipBasicStatsHelper(wndParent, tItemInfo, itemSource)
	local wndBox = nil
	local bSpecialBind = tItemInfo.tBind.bSoulbound or tItemInfo.tBind.bOnEquip or tItemInfo.tBind.bOnPickup
	if tItemInfo.tLevelRequirement or tItemInfo.tDurability or bSpecialBind or tItemInfo.tUnique or (tItemInfo.tStack and tItemInfo.tStack.nMaxCount ~= 1) or itemSource:GetPowerLevel() then
		wndBox = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "ItemTooltip_BasicStatsBox", wndParent)
	else
		return
	end

	local strTopLeft = ""
	local strBotLeft = ""
	local strSuperBotLeft = ""
	local strTopRight = ""
	local strBotRight = ""

	-- Level req
	if tItemInfo.tLevelRequirement then
		local strColor = tItemInfo.tLevelRequirement.bRequirementMet and kUIBody or kUIRed
		strTopLeft = string.format("<T TextColor=\"%s\">%s</T>", strColor, String_GetWeaselString(Apollo.GetString("Tooltips_ReqLevel"), tItemInfo.tLevelRequirement.nLevelRequired))
	else
		if itemSource:GetPowerLevel() > 0 then
			strTopLeft = string.format("<T TextColor=\"%s\">%s</T>", kUIBody, String_GetWeaselString(Apollo.GetString("Tooltips_BasePowerLevel"), itemSource:GetPowerLevel()))
		end
	end

	-- Durability Count
	if tItemInfo.tDurability then
		local nMax = tItemInfo.tDurability.nMax
		local nCurrent = tItemInfo.tDurability.nCurrent
		local nCurrentPercentage = nCurrent and (nCurrent / nMax) or 1

		local strFinishedString = ""
		if nCurrentPercentage == 0 then
			strFinishedString  = string.format("<T TextColor=\"%s\">%s</T>", kUIRed, nCurrent)
			strFinishedString = String_GetWeaselString(Apollo.GetString("Tooltips_DurabilityLow"), strFinishedString, nMax)
		elseif nCurrentPercentage <= 0.25 then
			strFinishedString  = string.format("<T TextColor=\"%s\">%s</T>", kUILowDurability, nCurrent)
			strFinishedString = String_GetWeaselString(Apollo.GetString("Tooltips_DurabilityLow"), strFinishedString, nMax)
		elseif nCurrentPercentage == 1 then
			strFinishedString = String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nMax, nMax)
		else
			strFinishedString = String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nCurrent, nMax)
		end

		-- Slot accordingly
		strBotLeft = strTopLeft ~= "" and string.format("<T TextColor=\"%s\">%s</T>", kUIBody, String_GetWeaselString(Apollo.GetString("Tooltips_Durability"), strFinishedString)) or strBotLeft
		strTopLeft = strTopLeft == "" and string.format("<T TextColor=\"%s\">%s</T>", kUIBody, String_GetWeaselString(Apollo.GetString("Tooltips_Durability"), strFinishedString)) or strTopLeft
	end



	-- Stack Count
	if tItemInfo.tStack and tItemInfo.tStack.nMaxCount ~= 1 then
		local strStackCount = ""
		if tItemInfo.tStack.nCount then
			strStackCount = String_GetWeaselString(Apollo.GetString("Tooltips_StackCountLimited"), tItemInfo.tStack.nCount, tItemInfo.tStack.nMaxCount)
		else
			strStackCount = String_GetWeaselString(Apollo.GetString("Tooltips_StackCount"), tItemInfo.tStack.nMaxCount)
		end
		strSuperBotLeft = (strTopLeft ~= "" and strBotLeft ~= "") and strStackCount or strSuperBotLeft
		strBotLeft = strTopLeft ~= "" and strStackCount or strBotLeft
		strTopLeft = strTopLeft == "" and strStackCount or strTopLeft
	end

	-- Soulbound
	if tItemInfo.tBind and tItemInfo.tBind.bSoulbound then
		strTopRight = Apollo.GetString("CRB_Soulbound")
	elseif tItemInfo.tBind and tItemInfo.tBind.bOnEquip then
		strTopRight = Apollo.GetString("CRB_Bind_on_equip")
	elseif tItemInfo.tBind and tItemInfo.tBind.bOnPickup then
		strTopRight = Apollo.GetString("CRB_Bind_on_pickup")
	end

	-- Unique
	if tItemInfo.tUnique then
		local strUniqueStr = ""
		if tItemInfo.tUnique.bUnique and tItemInfo.tUnique.nCount and tItemInfo.tUnique.nCount > 1 then
			strUniqueStr = String_GetWeaselString(Apollo.GetString("Tooltips_UniqueCount"), tItemInfo.tUnique.nCount)
		elseif tItemInfo.tUnique.bUnique then
			strUniqueStr = Apollo.GetString("CRB_Unique")
		elseif tItemInfo.tUnique.bEquipped then
			strUniqueStr = Apollo.GetString("Tooltips_UniqueEquipped")
		end

		-- Slot accordingly
		strBotRight = strTopRight ~= "" and strUniqueStr or strBotRight
		strTopRight = strTopRight == "" and strUniqueStr or strTopRight
	end

	-- Slot the stuff
	wndBox:FindChild("ItemTooltip_BasicStats_TopLeft"):SetAML("<P Font=\"CRB_InterfaceSmall\" TextColor=\""..kUIBody.."\">"..strTopLeft.."</P>")
	wndBox:FindChild("ItemTooltip_BasicStats_BotLeft"):SetAML("<P Font=\"CRB_InterfaceSmall\" TextColor=\""..kUIBody.."\">"..strBotLeft.."</P>")
	wndBox:FindChild("ItemTooltip_BasicStats_SuperBotLeft"):SetAML("<P Font=\"CRB_InterfaceSmall\" TextColor=\""..kUIBody.."\">"..strSuperBotLeft.."</P>")
	wndBox:FindChild("ItemTooltip_BasicStats_TopRight"):SetAML("<P Font=\"CRB_InterfaceSmall\" Align=\"Right\" TextColor=\""..kUIBody.."\">"..strTopRight.."</P>")
	wndBox:FindChild("ItemTooltip_BasicStats_BotRight"):SetAML("<P Font=\"CRB_InterfaceSmall\" Align=\"Right\" TextColor=\""..kUIBody.."\">"..strBotRight.."</P>")
	local nRowTwo = (strBotLeft == "" and strBotRight == "") and 0 or wndBox:FindChild("ItemTooltip_BasicStats_BotLeft"):GetHeight() -- nRowOne will always be visible
	local nRowThree = strSuperBotLeft == "" and 0 or wndBox:FindChild("ItemTooltip_BasicStats_SuperBotLeft"):GetHeight()

	local nLeft, nTop, nRight, nBottom = wndBox:GetAnchorOffsets()
	wndBox:SetAnchorOffsets(nLeft, nTop, nRight, nTop + wndBox:FindChild("ItemTooltip_BasicStats_TopLeft"):GetHeight() + nRowTwo + nRowThree)
end

-- #############################

local function ItemTooltipClassReqHelper(wndParent, tItemInfo)
	if tItemInfo.arClassRequirement then
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
		local strClasses = Apollo.GetString("Tooltips_ClassList")
		local strColor = tItemInfo.arClassRequirement.bRequirementMet and kUIGreen or kUIRed
		local strClassList = ""
		for idx, tCur in pairs (tItemInfo.arClassRequirement.arClasses) do
			if idx > 1 then
				strClassList = String_GetWeaselString(Apollo.GetString("Tooltips_ClassListItem"), strClassList, karClassToString[tItemInfo.arClassRequirement.arClasses[idx]])
			else
				strClassList = karClassToString[tItemInfo.arClassRequirement.arClasses[idx]]
			end
		end

		strClasses = String_GetWeaselString(strClasses, strClassList)

		wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", strColor, strClasses))
		wnd:SetHeightToContentHeight()
	end
end

-- #############################

local function ItemTooltipFactionReqHelper(wndParent, tItemInfo)
	if tItemInfo.tFactionRequirement then
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
		local strFaction = String_GetWeaselString(Apollo.GetString("Tooltips_Faction"), tItemInfo.tFactionRequirement.strFactionName)
		local strColor = tItemInfo.tFactionRequirement.bRequirementMet and kUIGreen or kUIRed

		wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", strColor, strFaction))
		wnd:SetHeightToContentHeight()
	end
end

-- #############################

local function ItemTooltipSpellReqHelper(wndParent, tItemInfo)
	if tItemInfo.arSpells then
		for idx, tCur in pairs(tItemInfo.arSpells) do
			if tCur.strFailure then
				local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)

				wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", kUIRed, tCur.strFailure))
				wnd:SetHeightToContentHeight()
			end
		end
	end
end

-- #############################

local function ItemTooltipAdditiveHelper(wndParent, tItemInfo)
	-- Additive Coordinate Effects
	if tItemInfo.tAdditive then
		local strCoordChange = String_GetWeaselString(Apollo.GetString("Tooltips_CoordChange"),tItemInfo.tAdditive.nVectorX, tItemInfo.tAdditive.nVectorY)
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
		wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", kUIBody, strCoordChange))
		wnd:SetHeightToContentHeight()
	end
end

-- #############################

local function ItemTooltipSchematicHelper(wndParent, tItemInfo)
	-- Tradeskill Schematic Details
	if tItemInfo.arTradeskillReqs then
		for nIdx,tTradeskillReqs in pairs(tItemInfo.arTradeskillReqs) do
			if tTradeskillReqs then
				local strTradeskillDetails = string.format(Apollo.GetString("CRB_Requires_Tradeskill_Tier"), tTradeskillReqs.strName, tTradeskillReqs.eTier)
				local strColor = kUIRed

				if tTradeskillReqs.bIsKnown then
					strTradeskillDetails = Apollo.GetString("CRB_Schematic_Already_Known")
				elseif tTradeskillReqs.bCanLearn then
					strColor = kUIGreen
				end

				local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
				wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", strColor, strTradeskillDetails))
				wnd:SetHeightToContentHeight()
			end
		end
	end
end

-- #############################

local function ItemTooltipSeparatorDiagonalHelper(wndParent)
	if #wndParent:GetChildren() > 1 then -- Separator is skipped if it's the very first element
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SeparatorDiagonal", wndParent)
	end
end

-- #############################

local function ItemTooltipSeparatorSmallLineHelper(wndParent)
	if #wndParent:GetChildren() > 1 then -- Separator is skipped if it's the very first element
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SeparatorSmallLine", wndParent)
	end
end

-- #############################

local function ItemTooltipInnatePropHelper(wndParent, tSortedInnatePropList, bUseDiff) -- E.G. Assault Power, Support Power, Armor, Shield
	if tSortedInnatePropList and #tSortedInnatePropList > 0 then
		ItemTooltipSeparatorDiagonalHelper(wndParent) -- Diagonal separator is skipped if it's the very first element
	end

	for idx, tCur in pairs (tSortedInnatePropList) do
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)

		local strLine = ""
		local nVal = tCur.nValue or 0
		local strProperty = Item.GetPropertyName(tCur.eProperty)

		if not tCur.nDiff or not bUseDiff then
			strLine = String_GetWeaselString(Apollo.GetString("Tooltips_StatEven"), nVal, strProperty)
		end

		if strLine == "" then -- Implied that tCur.nDiff is not 0 and bUseDiff is true
			local nDiffRound = math.floor(tCur.nDiff * 10) / 10
			if nVal == 0 and tCur.nDiff < 0 then -- stat is present on other item and we are 0 - all red
				strLine = string.format("<T TextColor=\"%s\">%s</T>", kUIRed, String_GetWeaselString(Apollo.GetString("Tooltips_StatDiffNew"), nVal, strProperty, nDiffRound))
			elseif nVal ~= 0 then
				if tCur.nDiff == nVal then -- stat not present on other item, we are all green
					strLine = string.format("<T TextColor=\"%s\">%s</T>", kUIGreen, String_GetWeaselString(Apollo.GetString("Tooltips_StatLost"), nVal, strProperty, nDiffRound))
				elseif tCur.nDiff > 0 then -- stat present on other item, but we are higher. Diff is green
					local strDiff = string.format("<T TextColor=\"%s\">%s</T>", kUIGreen, String_GetWeaselString(Apollo.GetString("Tooltips_StatUp"), nDiffRound))
					strLine = String_GetWeaselString(Apollo.GetString("Tooltips_StatDiff"), nVal, strProperty, strDiff)
				elseif tCur.nDiff < 0 then -- we are lower than other item : diff is red
					local strDiff = string.format("<T TextColor=\"%s\">%s</T>", kUIRed, String_GetWeaselString(Apollo.GetString("Tooltips_StatDown"), nDiffRound))
					strLine = String_GetWeaselString(Apollo.GetString("Tooltips_StatDiff"), nVal, strProperty, strDiff)
				elseif tCur.nDiff == 0 then -- we match other item, so no color change
					strLine = String_GetWeaselString(Apollo.GetString("Tooltips_StatEven"), nVal, strProperty)
				end
			end
		end

		wnd:SetAML(string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kUIHugeFontSize, kUITeal, strLine))
		wnd:SetHeightToContentHeight()
	end
end

-- #############################

local function ItemTooltipBudgetPropHelper(wndParent, tblSortedBudgetPropList, bUseDiff, tItemInfo) -- E.G. Moxie, Grit, Brutality
	for idx, tCur in pairs(tblSortedBudgetPropList) do
		local wndBudgetFirst = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)

		local strLine = ""
		local nVal = tCur.nValue or 0
		local strProperty = Item.GetPropertyName(tCur.eProperty)

		if not tCur.nDiff or not bUseDiff then
			strLine = String_GetWeaselString(Apollo.GetString("Tooltips_StatEven"), nVal, strProperty)
		end

		if strLine == "" then -- Implicit bUseDiff
			local nDiffRound = math.floor(tCur.nDiff * 10) / 10
			if nVal == 0 and tCur.nDiff < 0 then -- stat is present on other item and we are 0 - all red
				strLine = string.format("<T TextColor=\"%s\">%s</T>", kUIRed, String_GetWeaselString(Apollo.GetString("Tooltips_StatDiffNew"), nVal, strProperty, nDiffRound))
			elseif nVal ~= 0 then
				if tCur.nDiff == nVal then -- stat not present on other item, we are all green
					strLine = string.format("<T TextColor=\"%s\">%s</T>", kUIGreen, String_GetWeaselString(Apollo.GetString("Tooltips_StatLost"), nVal, strProperty, nDiffRound))
				elseif tCur.nDiff > 0 then -- stat present on other item, but we are higher. Diff is green
					local strDiff = string.format("<T TextColor=\"%s\">%s</T>", kUIGreen, String_GetWeaselString(Apollo.GetString("Tooltips_StatUp"), nDiffRound))
					strLine = String_GetWeaselString(Apollo.GetString("Tooltips_StatDiff"), nVal, strProperty, strDiff)
				elseif tCur.nDiff < 0 then -- we are lower than other item : diff is red
					local strDiff = string.format("<T TextColor=\"%s\">%s</T>", kUIRed, String_GetWeaselString(Apollo.GetString("Tooltips_StatDown"), nDiffRound))
					strLine = String_GetWeaselString(Apollo.GetString("Tooltips_StatDiff"), nVal, strProperty, strDiff)
				elseif tCur.nDiff == 0 then -- we match other item, so no color change
					strLine = String_GetWeaselString(Apollo.GetString("Tooltips_StatEven"), nVal, strProperty)
				end
			end
		end

		wndBudgetFirst:SetAML(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", kUIBody, strLine))
		wndBudgetFirst:SetHeightToContentHeight()

		-- Derived if there are any
		if tCur.nDiff and bUseDiff and not tItemInfo.arRandomProperties then
			for idxD, tCurD in pairs(tCur.arDerived or {}) do
				local wndD = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)

				local strLineD = ""
				local nValD = tCurD.nValue or 0
				local strPropertyNameD = Item.GetPropertyName(tCurD.eProperty)

				if not tCurD.nDiff or not bUseDiff or tCurD.nDiff == 0 then
					strLineD = string.format("<T TextColor=\"%s\">%s%s</T>", kUIYellow, kstrTab, String_GetWeaselString(Apollo.GetString("Tooltips_StatFloat"), nValD, strPropertyNameD))
				end

				if strLineD == "" then -- Implicit bUseDiff
					local nDiffRoundD = (math.floor(tCurD.nDiff * 10)) / 10
					if nDiffRoundD >= 0 and nValD >= nDiffRoundD then
						local strNewDiff = String_GetWeaselString(Apollo.GetString("Tooltips_StatDiffNewFloat"), nValD, strPropertyNameD, nDiffRoundD)
						strLineD = string.format("<T TextColor=\"%s\">%s%s</T>", kUIGreen, kstrTab, strNewDiff)
					elseif nDiffRoundD >= 0 then
						local strDiff = string.format("<T TextColor=\"%s\">%s</T>", kUIGreen, String_GetWeaselString(Apollo.GetString("Tooltips_StatUpFloat"), nDiffRoundD))
						strLineD = string.format("<T TextColor=\"%s\">%s%s</T>", kUIYellow, kstrTab, String_GetWeaselString(Apollo.GetString("Tooltips_StatDiffFloat"),nValD, strPropertyNameD, strDiff))
					elseif nValD == 0 then
						local strEven = String_GetWeaselString(Apollo.GetString("Tooltips_StatEvenFloat"), nValD, strPropertyNameD, nDiffRoundD)
						strLineD = string.format("<T TextColor=\"%s\">%s%s</T>", kUIRed, kstrTab, strEven)
					else
						local strDiff = string.format("<T TextColor=\"%s\">%s</T>", kUIRed, String_GetWeaselString(Apollo.GetString("Tooltips_StatDownFloat"), nDiffRoundD))
						strLineD = string.format("<T TextColor=\"%s\">%s%s</T>", kUIYellow, kstrTab, String_GetWeaselString(Apollo.GetString("Tooltips_StatDiffFloat"), nValD, strPropertyNameD, strDiff))
					end
				end

				wndD:SetAML(string.format("<T Font=\"CRB_InterfaceSmall\">%s</T>", strLineD))
				wndD:SetHeightToContentHeight()
			end
		end
	end

	if tItemInfo.arRandomProperties then
		for idx, tData in pairs(tItemInfo.arRandomProperties) do
			if not bMadeHeader then
				bMadeHeader = true
				ItemTooltipSeparatorSmallLineHelper(wndParent)
			end

			local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
			wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", kUIBody, String_GetWeaselString(Apollo.GetString("Tooltips_PlusProperty"), tData.strName)))

			wnd:SetHeightToContentHeight()
		end
	end
end

-- #############################

local function ItemTooltipEmptySocketsHelper(wndParent, tItemInfo, itemSource)
	local bMadeHeader = false
	for idx, tSocket in ipairs(itemSource:GetEmptySockets() or {}) do
		if not tSocket.bIsLocked then
			if not bMadeHeader then
				bMadeHeader = true
				ItemTooltipSeparatorSmallLineHelper(wndParent)
			end

			local strSocketType = ""
			local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
			if tSocket.eType == Item.CodeEnumMicrochipType.Stat then
				strSocketType = String_GetWeaselString(Apollo.GetString("Tooltips_AnyAttributeEmpty"), tSocket.nValue)
			else
				strSocketType = String_GetWeaselString(Apollo.GetString("Tooltips_EmptySocket"), ktMicrochipTypeNames[tSocket.eType])
			end
			wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", kUIBody, strSocketType))
			wnd:SetHeightToContentHeight()
		end
	end

	local tSigils = tItemInfo.tSigils -- GOTCHA: This is provided data
	if not tSigils then
		tSigils = itemSource:GetSigils() -- GOTCHA: This default data
	end

	if tSigils and not tSigils.bIsDefined and tSigils.nMaximum and tSigils.nMaximum ~= 0 then
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
		if tSigils.nMinimum == tSigils.nMaximum then
			wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", kUIBody, String_GetWeaselString(Apollo.GetString("Tooltips_RuneSlotsStatic"), tSigils.nMaximum)))
		else
			wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", kUIBody, String_GetWeaselString(Apollo.GetString("Tooltips_RuneSlotsRange"), tSigils.nMinimum, tSigils.nMaximum)))
		end
		wnd:SetHeightToContentHeight()
	end
end

-- #############################

local function ItemTooltipChargeHelper(wndParent, tItemInfo)
	-- Charge Count
	if tItemInfo.tCharge and tItemInfo.tCharge.nMaxCount ~= 1 then
		ItemTooltipSeparatorDiagonalHelper(wndParent)

		-- If no data for the nCount was populated we have none
		if tItemInfo.tCharge.nCount == nil then
			tItemInfo.tCharge.nCount = 0
		end

		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
		wnd:SetAML(string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kUIHugeFontSize, kUITeal, String_GetWeaselString(Apollo.GetString("Tooltips_ChargeCount"), tItemInfo.tCharge.nCount, tItemInfo.tCharge.nMaxCount)))
		wnd:SetHeightToContentHeight()
	end
end

-- #############################

local function ItemTooltipSpellEffectHelper(wndParent, tItemInfo)
	-- Spell Effects
	if tItemInfo.arSpells then
		for idx, tCur in pairs(tItemInfo.arSpells) do
			local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
			local strResult = ""
			if tCur.bActivate then
				strResult = String_GetWeaselString(Apollo.GetString("Tooltips_OnUse"), tCur.strName)
			elseif tCur.bOnEquip then
				strResult = String_GetWeaselString(Apollo.GetString("Tooltips_OnSpecial"), tCur.strName)
			elseif tCur.bProc then
				strResult = String_GetWeaselString(Apollo.GetString("Tooltips_OnSpecial"), tCur.strName)
			end

			if strResult ~= "" then
				local strItemSpellEffect = String_GetWeaselString(Apollo.GetString("Tooltips_ItemSpellEffect"), strResult, (tCur.strFlavor or ""))
				wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", kUIBody, strItemSpellEffect))
				local nWidth, nHeight = wnd:SetHeightToContentHeight()
				local nLeft, nTop, nRight, nBottom = wnd:GetAnchorOffsets()
				wnd:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 15)

			end
		end
	end

	-- Ability Chip Info
	if tItemInfo.tChipInfo and tItemInfo.tChipInfo.arSpells then
		for idx, tCur in pairs(tItemInfo.tChipInfo.arSpells) do
			local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
			local strResult = ""
			if tCur.bActivate then
				strResult = String_GetWeaselString(Apollo.GetString("Tooltips_OnUse"), tCur.strName)
			elseif tCur.bOnEquip then
				strResult = String_GetWeaselString(Apollo.GetString("Tooltips_OnSpecial"), tCur.strName)
			elseif tCur.bProc then
				strResult = String_GetWeaselString(Apollo.GetString("Tooltips_OnSpecial"), tCur.strName)
			end

			if strResult ~= "" then
				local strFinal = String_GetWeaselString(Apollo.GetString("Tooltips_ItemSpellEffect"), strResult, (tCur.strFlavor or ""))
				wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", kUIBody, strFinal))
				wnd:SetHeightToContentHeight()
			end
		end
	end

end

-- #############################
local function ItemTooltipImbuementHelper(wndParent, tItemInfo)
	-- Imbuements
	if tItemInfo.arImbuements then
		ItemTooltipSeparatorDiagonalHelper(wndParent)

		local nCompletedCount = 0
		local nTotalCount = 0

		for idx, tCur in pairs(tItemInfo.arImbuements) do
			if tCur.bComplete then
				nCompletedCount = nCompletedCount + 1
			end
			nTotalCount = nTotalCount + 1
		end

		local wndFirst = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
		local strImbuementProgress = String_GetWeaselString(Apollo.GetString("Tooltips_Imbuement"), nCompletedCount, nTotalCount)
		wndFirst:SetAML(string.format("<P Font=\"%s\" TextColor=\"%s\">%s</P>", kUIHugeFontSize, kUITeal, strImbuementProgress))
		wndFirst:SetHeightToContentHeight()

		for idx, tCur in pairs(tItemInfo.arImbuements) do
			if tCur.bActive or tCur.bComplete then
				local strCompleteColor = tCur.bComplete and kUIBody or kUIGreen

				if not tCur.bComplete and tCur.strObjective then
					local wndChallegeName = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
					wndChallegeName:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", strCompleteColor, tCur.strName))
					wndChallegeName:SetHeightToContentHeight()

					local wndObjective = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
					wndObjective:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", strCompleteColor, tCur.strObjective))
					wndObjective:SetHeightToContentHeight()
				end

				if tCur.strSpecial then
					local strCurrSpecial = String_GetWeaselString(Apollo.GetString("Tooltips_OnSpecial"), tCur.strSpecial)
					local wndSpecial = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
					wndSpecial:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", strCompleteColor, strCurrSpecial))
					wndSpecial:SetHeightToContentHeight()
				end

				if tCur.eProperty and tCur.nValue then
					local strProperty = String_GetWeaselString(Apollo.GetString("Tooltips_StatEven"), tCur.nValue, Item.GetPropertyName(tCur.eProperty))
					local wndProperty = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
					wndProperty:SetAML(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strCompleteColor, strProperty))
					wndProperty:SetHeightToContentHeight()
				end
			end
		end
	end
end

-- #############################

local function ItemTooltipQuestHelper(wndParent, tItemInfo)
	-- Quest
	if tItemInfo.nQuestMinLevel then
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
		wnd:SetAML(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", kUIBody, String_GetWeaselString(Apollo.GetString("Tooltips_UseToStartQuest"), tItemInfo.nQuestMinLevel)))
		wnd:SetHeightToContentHeight()
	end
end

-- #############################

local function ItemTooltipSigilHelper(wndParent, tItemInfo, itemSource) -- Drawing runes on an item, not if mousing over a rune item
	-- TODO: FORMATTING w/ ICONS
	local tSigils = tItemInfo.tSigils -- GOTCHA: This is provided data
	if not tSigils then
		tSigils = itemSource:GetSigils() -- GOTCHA: This is default data
	end

	if tSigils and tSigils.arSigils then
		ItemTooltipSeparatorSmallLineHelper(wndParent)

		local nHeight = 0
		local wndBox = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "ItemTooltip_RuneBox", wndParent)

		for idx, tCur in pairs(tSigils.arSigils) do
			if karSigilTypeToString[tCur.eElement] then
				local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "ItemTooltip_Rune", wndBox)
				local itemSigil = tCur.itemSigil
				if itemSigil then
					wnd:FindChild("ItemTooltip_RuneIcon"):SetSprite(itemSigil:GetIcon())

					-- TODO FIX! This is faulty logic and won't work if there's more than one rune giving bonuses
					-- TODO: Use tCur.eProperty and tCur.nValue
					-- TODO: If a rune just shows set

					if tCur.nValue and tCur.nValue > 0 then
						wnd:FindChild("ItemTooltip_RuneText"):SetText(String_GetWeaselString(Apollo.GetString("Tooltips_RuneAttributeBonus"), tCur.nValue, (ktAttributeToText[tCur.eProperty] or "")))
					else
						wnd:FindChild("ItemTooltip_RuneText"):SetText(itemSigil:GetName()) -- Shouldn't happen
					end
				else
					local strElement = karSigilTypeToString[tCur.eElement]
					local strText = tCur.bUnlocked and String_GetWeaselString(Apollo.GetString("Tooltips_RuneSlotOpen"), strElement) or String_GetWeaselString(Apollo.GetString("Tooltips_RuneSlotLocked"), strElement)
					wnd:FindChild("ItemTooltip_RuneIcon"):SetSprite(karSigilTypeToIcon[tCur.eElement])
					wnd:FindChild("ItemTooltip_RuneText"):SetText(strText)
				end

				-- If it's the only item, use the full space
				if #tSigils.arSigils == 1 then
					local nLeft, nTop, nRight, nBottom = wnd:GetAnchorOffsets()
					wnd:SetAnchorOffsets(nLeft, nTop, wndBox:GetWidth() / 2, nBottom)
				end
			end
		end

		wndBox:ArrangeChildrenTiles(0)
		local nNumChildren = #wndBox:GetChildren()
		local nLeft, nTop, nRight, nBottom = wndBox:GetAnchorOffsets()
		wndBox:SetAnchorOffsets(nLeft, nTop, nRight, nTop + (math.ceil(nNumChildren / 2) * 43))
	end
end

-- #############################

local function ItemTooltipRuneHelper(wndParent, tItemInfo) -- If mousing over a rune item, not drawing runes on an item
	-- Note: The raw stats (e.g. + A lot of Brutality) exists on flavor text for now
	if tItemInfo.tRuneInfo and tItemInfo.tRuneInfo.tSet then
		ItemTooltipSeparatorSmallLineHelper(wndParent) -- Diagonal separator is skipped if it's the very first element

		local tSetData = tItemInfo.tRuneInfo.tSet
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
		wnd:SetAML(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", kUIGreen, String_GetWeaselString(Apollo.GetString("EngravingStation_RuneSetText"), tSetData.strName, tSetData.nCurrentPower, tSetData.nMaxPower)))
		wnd:SetHeightToContentHeight()

		-- Now loop through the sets
		local tBonuses = tSetData.arBonsues
		table.sort(tBonuses, function(a,b) return a.nRequiredPower < b.nRequiredPower end)

		for idx, tCur in pairs(tBonuses) do
			local strColor = tCur.bActive and kUIGreen or "UI_TextHoloBodyCyan"
			local wndBonus = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
			wndBonus:SetAML(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strColor, String_GetWeaselString(Apollo.GetString("Tooltips_RuneDetails"), tCur.nRequiredPower, tCur.strName, tCur.strFlavor or "")))
			wndBonus:SetHeightToContentHeight()
		end
	end
end

-- #############################

local function ItemTooltipFlavorHelper(wndParent, tItemInfo)
	local strResult = ""

	if tItemInfo.strFlavor and string.len(tItemInfo.strFlavor) > 0 then
		strResult = string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextMetalBodyHighlight\">%s</P>", tItemInfo.strFlavor)
	end

	if tItemInfo.bDestroyOnLogout then
		strResult = string.format("%s<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextMetalBodyHighlight\">%s</P>", strResult, Apollo.GetString("Tooltip_DestroyedOnLogout"))
	end

	if tItemInfo.bDestroyOnZone then
		strResult = string.format("%s<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextMetalBodyHighlight\">%s</P>", strResult, Apollo.GetString("Tooltip_DestroyedOnZone"))
	end

	if tItemInfo.tExpirationTimeRemaining ~= nil and tItemInfo.tExpirationTimeRemaining.nMinutes > 0 and tItemInfo.tExpirationTimeRemaining.nSeconds > 0 then
		local nMinutes = tItemInfo.tExpirationTimeRemaining.nMinutes
		local nSeconds = tItemInfo.tExpirationTimeRemaining.nSeconds
		strResult = string.format("%s<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextMetalBodyHighlight\">%s</P>", strResult, String_GetWeaselString(Apollo.GetString("Tooltip_ExpiringTime"), nMinutes, nSeconds))
	elseif (tItemInfo.nExpirationTime and tItemInfo.nExpirationTime or 0) > 0 then
		local nMinutes = tItemInfo.nExpirationTime
		strResult = string.format("%s<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextMetalBodyHighlight\">%s</P>", strResult, String_GetWeaselString(Apollo.GetString("Tooltip_ExpireTime"), nMinutes))
	end

	if tItemInfo.strMakersMark and string.len(tItemInfo.strMakersMark) > 0 then
		local strFormatted = string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextMetalBodyHighlight\">%s</P>", tItemInfo.strMakersMark)
		strResult = string.format("%s<P Font=\"CRB_InterfaceSmall\" TextColor=\"UI_TextMetalBodyHighlight\">%s</P>", strResult, String_GetWeaselString(Apollo.GetString("Tooltips_CraftedBy"), strResult, strFormatted))
	end

	if strResult == " " or string.len(strResult) == 0 then
		return
	end

	local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "ItemTooltip_Flavor", wndParent)
	wnd:FindChild("ItemTooltip_FlavorML"):SetAML(strResult)

	-- Resize
	local nTextWidth, nTextHeight = wnd:FindChild("ItemTooltip_FlavorML"):SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = wnd:GetAnchorOffsets()
	wnd:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nTextHeight + 23)
end

-- #############################

local function ItemTooltipMonHelper(wndParent, tItemInfo, itemSource, tFlags) -- Sell, Buy, Buy Back, Repair
	if not tItemInfo.tCost or tFlags.bInvisibleFrame then -- bInvisibleFrame is mainly used for crafting
		return
	end

	-- Buy requirements, e.g. 2000 Reputation
	if (tFlags.bBuying or tFlags.nPrereqVendorId) and (itemSource ~= tFlags.itemCompare) then
		local unitPlayer = GameLib.GetPlayerUnit()
		local tPrereqInfo = unitPlayer and unitPlayer:GetPrereqInfo(tFlags.nPrereqVendorId) or nil
		if tPrereqInfo and tPrereqInfo.strText then
			local strColor = tPrereqInfo.bIsMet and kUIBody or kUIRed
			local wndPrereq = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndParent)
			wndPrereq:SetAML(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</T>", strColor, String_GetWeaselString(tPrereqInfo.strText)))
			wndPrereq:SetHeightToContentHeight()
		end
	end

	-- If we're drawing at least one thing do a separator and a wndBox
	local wndBox = nil
	local bCanRepair = tItemInfo.tCost.monRepair and tItemInfo.tCost.monRepair:GetAmount() ~= 0
	if tItemInfo.bSalvagable or tFlags.bBuying or tFlags.bBuyback or tItemInfo.tCost.arMonSell or bCanRepair then
		ItemTooltipSeparatorSmallLineHelper(wndParent)
		wndBox = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "ItemTooltip_SalvageAndMoney", wndParent)
	end

	-- Salvage
	if tItemInfo.bSalvagable and not tFlags.bBuying then
		wndBox:SetText(tItemInfo.bAutoSalvage and Apollo.GetString("Tooltips_RightClickSalvage") or Apollo.GetString("Tooltips_Salvageable"))
		wndBox:SetTextColor("UI_TextHoloBodyCyan")
	end

	-- Buy Buyback
	local nStackCount = tItemInfo.tStack and tItemInfo.tStack.nCount or 1
	if (tFlags.bBuying or tFlags.bBuyback) and tItemInfo.tCost.arMonBuy then
		for idx, tCur in pairs(tItemInfo.tCost.arMonBuy) do
			local monPrice = tCur
			if monPrice:GetAmount() ~= 0 then
				local strSellCaption = Apollo.GetString("CRB_Buy_For").."<T TextColor=\"0\">.</T>"
				if nStackCount > 1 then
					monPrice:SetAmount(monPrice:Multiply(nStackCount))
				end

				local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndBox)
				xml = XmlDoc.new()
				xml:AddLine(strSellCaption, "UI_TextHoloBodyCyan", "CRB_InterfaceSmall", "Right")
				monPrice:AppendToTooltip(xml)
				wnd:SetDoc(xml)
				wnd:SetHeightToContentHeight()
			end
		end
	end

	-- Sell
	local bHasSellPrice = false
	if tItemInfo.tCost.arMonSell then -- tFlags.bSelling
		for idx, tCur in pairs(tItemInfo.tCost.arMonSell) do
			local monPrice = tCur
			if monPrice:GetAmount() ~= 0 then
				bHasSellPrice = true

				local strSellCaption = Apollo.GetString("CRB_Sell_for_").."<T TextColor=\"0\">.</T>"
				if nStackCount > 1 then
					monPrice = monPrice:Multiply(nStackCount)
				end

				local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndBox)
				xml = XmlDoc.new()
				xml:AddLine(strSellCaption, "UI_TextHoloBodyCyan", "CRB_InterfaceSmall", "Right")
				monPrice:AppendToTooltip(xml)
				wnd:SetDoc(xml)
				wnd:SetHeightToContentHeight()
			end
		end
	end

	if tItemInfo.tCost.bHasRestockingFee then
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndBox)
		xml = XmlDoc.new()
		xml:AddLine(Apollo.GetString("CRB_RestockFee"), "UI_TextHoloBodyCyan", "CRB_InterfaceSmall", "Right")
		wnd:SetDoc(xml)
		wnd:SetHeightToContentHeight()
	end

	if bHasSellPrice and tItemInfo.tCost.tReturnTimeLeft then
		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndBox)

		local nTimeMinutes = tonumber(tItemInfo.tCost.tReturnTimeLeft.nMin)
		local tTimeInfo = {["name"] = Apollo.GetString("CRB_Min"), ["count"] = nTimeMinutes}
		local strTimeRemaining = String_GetWeaselString(Apollo.GetString("CRB_SellToVendorTime"), tTimeInfo)

		xml = XmlDoc.new()
		xml:AddLine(strTimeRemaining, "UI_TextHoloBodyCyan", "CRB_InterfaceSmall", "Right")
		wnd:SetDoc(xml)
		wnd:SetHeightToContentHeight()
	end

	-- Repair
	if bCanRepair then
		local monPrice = tItemInfo.tCost.monRepair
		local strSellCaption = Apollo.GetString("Tooltips_RepairFor") .. "<T TextColor=\"0\">.</T>"
		if nStackCount > 1 then
			monPrice = monPrice:Multiply(nStackCount)
		end

		local wnd = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SimpleRowSmallML", wndBox)
		xml = XmlDoc.new()
		xml:AddLine(strSellCaption, "UI_TextHoloBodyCyan", "CRB_InterfaceSmall", "Right")
		monPrice:AppendToTooltip(xml)
		wnd:SetDoc(xml)
		wnd:SetHeightToContentHeight()
	end

	-- Resize
	if wndBox and wndBox:IsValid() then
		local nHeight = wndBox:ArrangeChildrenVert(0)
		local nLeft, nTop, nRight, nBottom = wndBox:GetAnchorOffsets()
		wndBox:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.max(20, nHeight)) -- Min size if just the salvage text
	end
end

-- #############################

local function ItemTooltipPropSortHelper(tItemInfo)
	local tSorted = {}
	if not tItemInfo then
		return {}
	end

	local function fnSort(a,b)
		if a.nSortOrder and b.nSortOrder then
			return a.nSortOrder < b.nSortOrder
		elseif b.nSortOrder then
			return true
		else
			return false
		end
	end

	tSorted = tItemInfo
	table.sort(tSorted, fnSort)

	for idx, tCur in pairs(tSorted) do
		if tCur.arDerived then -- Table within a table
			table.sort(tSorted[idx].arDerived, fnSort)
		end
	end

	return tSorted
end

-- Item Tooltip Generate

local function GenerateItemTooltipForm(luaCaller, wndParent, itemSource, tFlags, nCount)
	if not itemSource then
		return
	end

	wndParent:SetTooltipDoc(nil)
	wndParent:SetTooltipDocSecondary(nil)

	local tSource = { itemSource, tFlags.itemModData, tFlags.tGlyphData, tFlags.arGlyphIds, tFlags.strMaker }
	local tItemInfo = tFlags.itemCompare and Item.GetDetailedInfo(tSource, tFlags.itemCompare) or Item.GetDetailedInfo(tSource)

	local wndTooltip = nil
	local wndTooltipComp = nil
	if tFlags.bPermanent then
		wndTooltip = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "ItemTooltip_Base", tFlags.wndParent, luaCaller)
		if tFlags.bNotEquipped then
			wndTooltip:FindChild("CurrentHeader"):Show(false)
		end
	else
		wndTooltip = wndParent:LoadTooltipForm("ui\\Tooltips\\TooltipsForms.xml", "ItemTooltip_Base", luaCaller)
		if tItemInfo.tCompare then
			wndTooltipComp = wndParent:LoadTooltipFormSecondary("ui\\Tooltips\\TooltipsForms.xml", "ItemTooltip_Base", luaCaller)
		end
		if tFlags.bNotEquipped == false then
			wndTooltip:FindChild("CurrentHeader"):Show(true)
		else
			wndTooltip:FindChild("CurrentHeader"):Show(false)
		end
	end

	local wndItems = wndTooltip:FindChild("Items")
	local wndItemsCompare = wndTooltipComp and wndTooltipComp:FindChild("Items") or nil
	local tPrimaryInnateSort = {}
	local tPrimaryBudgetBasedSort = {}
	local tCompareInnateSort = {}
	local tCompareBudgetBasedSort = {}

	-- After resizing, now draw
	local function CallAllHelpers(wndTooltip, wndItems, itemOne, itemTwo, tFlags, tPrimaryInate, tPrimaryBudget, bPropHelper)
		ItemTooltipHeaderHelper(wndItems, itemOne, itemTwo, wndTooltip, tFlags)
		--
		ItemTooltipBasicStatsHelper(wndItems, itemOne, itemTwo)
		ItemTooltipClassReqHelper(wndItems, itemOne)
		ItemTooltipFactionReqHelper(wndItems, itemOne)
		ItemTooltipSpellReqHelper(wndItems, itemOne)
		ItemTooltipSchematicHelper(wndItems, itemOne)
		ItemTooltipAdditiveHelper(wndItems, itemOne)
		--
		ItemTooltipInnatePropHelper(wndItems, tPrimaryInate, bPropHelper)
		ItemTooltipBudgetPropHelper(wndItems, tPrimaryBudget, bPropHelper, itemOne)
		--
		ItemTooltipChargeHelper(wndItems, itemOne)
		ItemTooltipSpellEffectHelper(wndItems, itemOne)
		--
		ItemTooltipEmptySocketsHelper(wndItems, itemOne, itemTwo)
		--
		ItemTooltipImbuementHelper(wndItems, itemOne)
		ItemTooltipQuestHelper(wndItems, itemOne)
		--
		ItemTooltipSigilHelper(wndItems, itemOne, itemTwo)
		ItemTooltipRuneHelper(wndItems, itemOne)
		ItemTooltipFlavorHelper(wndItems, itemOne)
		--
		ItemTooltipMonHelper(wndItems, itemOne, itemTwo, tFlags)
	end

	if tItemInfo.tPrimary and wndTooltip then
		wndTooltip:FindChild("ItemTooltip_BaseCanEquip"):Show(itemSource:IsEquippable() and not itemSource:CanEquip())
		wndTooltip:FindChild("ItemTooltip_BaseRarityFrame"):SetSprite(karItemQualityToBorderFrameBG[tItemInfo.tPrimary.eQuality] or "")
	end

	if tItemInfo.tCompare and wndTooltipComp then
		wndTooltipComp:FindChild("ItemTooltip_BaseCanEquip"):Show(tFlags.itemCompare:IsEquippable() and not tFlags.itemCompare:CanEquip())
		wndTooltipComp:FindChild("ItemTooltip_BaseRarityFrame"):SetSprite(karItemQualityToBorderFrameBG[tItemInfo.tCompare.eQuality] or "")
	end

	-- This is mainly used for crafting
	local nInvisibleFramePadding = 0
	if tFlags.bInvisibleFrame then
		nInvisibleFramePadding = 10
		wndTooltip:FindChild("ItemTooltipBG"):Show(false)
		wndTooltip:FindChild("ItemTooltip_BaseCanEquip"):Show(false)
		wndTooltip:FindChild("ItemTooltip_BaseRarityFrame"):Show(false)
		if wndTooltipComp then
			wndTooltipComp:FindChild("ItemTooltipBG"):Show(false)
			wndTooltipComp:FindChild("ItemTooltip_BaseCanEquip"):Show(false)
			wndTooltipComp:FindChild("ItemTooltip_BaseRarityFrame"):Show(false)
		end
	end

	if tItemInfo.tPrimary and wndTooltip and wndTooltip:IsValid() and wndItems and wndItems:IsValid() then
		if tItemInfo.tPrimary.arInnateProperties then
			tPrimaryInnateSort = ItemTooltipPropSortHelper(tItemInfo.tPrimary.arInnateProperties)
		end
		if tItemInfo.tPrimary.arBudgetBasedProperties then
			tPrimaryBudgetBasedSort = ItemTooltipPropSortHelper(tItemInfo.tPrimary.arBudgetBasedProperties)
		end

		CallAllHelpers(wndTooltip, wndItems, tItemInfo.tPrimary, itemSource, tFlags, tPrimaryInnateSort, tPrimaryBudgetBasedSort, true)
	end

	--Compare (Equipped)
	if tItemInfo.tCompare and wndTooltipComp and wndItemsCompare and wndTooltipComp:IsValid() and wndItemsCompare:IsValid() then
		if tItemInfo.tCompare.arInnateProperties then
			tCompareInnateSort = ItemTooltipPropSortHelper(tItemInfo.tCompare.arInnateProperties)
		end

		if tItemInfo.tCompare.arBudgetBasedProperties then
			tCompareBudgetBasedSort = ItemTooltipPropSortHelper(tItemInfo.tCompare.arBudgetBasedProperties)
		end

		CallAllHelpers(wndTooltipComp, wndItemsCompare, tItemInfo.tCompare, tFlags.itemCompare, tFlags, tCompareInnateSort, tCompareBudgetBasedSort, false)
	end

	-- GOTCHA: There is only one draw pass, so XML must match kItemTooltipWindowWidth, otherwise text calculation may be wrong
	wndTooltip:Move(0, 0, kItemTooltipWindowWidth, wndItems:ArrangeChildrenVert(0) + nInvisibleFramePadding + knWndHeightBuffer)
	if tItemInfo.tCompare and wndTooltipComp and wndTooltipComp:IsValid() then
		wndTooltipComp:Move(0, 0, kItemTooltipWindowWidth, wndItemsCompare:ArrangeChildrenVert(0) + nInvisibleFramePadding + knWndHeightBuffer)
	end

	return wndTooltip, wndTooltipComp
end

-------------------
-- Spell Tooltip --
-------------------

local function GenerateSpellTooltipForm(luaCaller, wndParent, splSource, tFlags)

	-- Initial Bad Data Checks
	if splSource == nil then
		return
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then
		return
	end

	local wndTooltip
	if tFlags and tFlags.bPermanent then
		wndTooltip = Apollo.LoadForm("ui\\Tooltips\\TooltipsForms.xml", "SpellTooltip_Base", tFlags.wndParent, luaCaller)
	else
		wndTooltip = wndParent:LoadTooltipForm("ui\\Tooltips\\TooltipsForms.xml", "SpellTooltip_Base", luaCaller)
	end

	--TopDataBlock
	local wndTopDataBlock 		= wndTooltip:FindChild("TopDataBlock")
	local wndName 				= wndTopDataBlock:FindChild("NameString")
	local wndTier 				= wndTopDataBlock:FindChild("TierString")
	local wndCastInfo 			= wndTopDataBlock:FindChild("CastInfoString")
	local wndRange 				= wndTopDataBlock:FindChild("RangeString")
	local wndCost				= wndTopDataBlock:FindChild("CostString")
	local wndTargeting			= wndTopDataBlock:FindChild("TargetingString")
	local wndCooldown			= wndTopDataBlock:FindChild("CooldownString")
	local wndMobility			= wndTopDataBlock:FindChild("MobilityString")
	local wndCharges			= wndTopDataBlock:FindChild("ChargesString")
	local wndGeneralDescription = wndTooltip:FindChild("GeneralDescriptionString")

    -- Name
	wndName:SetAML(string.format("<P Font=\"CRB_HeaderSmall\" TextColor=\"UI_TextHoloTitle\">%s</P>", splSource:GetName()))

	-- Tier
	local nTier = splSource:GetTier() - 1
	local strTier = nTier == 0 and Apollo.GetString("ToolTip_BaseLowercase") or String_GetWeaselString(Apollo.GetString("Tooltips_Tier"), nTier)
	wndTier:SetText(strTier)

    -- Cast Info
	local fCastTime
	local strCastInfo = splSource:GetCastInfoString()
	local eCastMethod = splSource:GetCastMethod()
	local tChannelData = splSource:GetChannelData()

	if strCastInfo and strCastInfo ~= "" then
		fCastTime = splSource:GetCastTimeOverride()
	else
		if eCastMethod == Spell.CodeEnumCastMethod.Channeled or eCastMethod == Spell.CodeEnumCastMethod.ChanneledField then
			fCastTime = tChannelData.fMaxTime
		elseif eCastMethod == Spell.CodeEnumCastMethod.PressHold or eCastMethod == Spell.CodeEnumCastMethod.ChargeRelease then
			fCastTime = splSource:GetThresholdTime()
		else
			fCastTime = splSource:GetCastTime()
		end

		if eCastMethod == Spell.CodeEnumCastMethod.Normal or eCastMethod == Spell.CodeEnumCastMethod.Multiphase or eCastMethod == Spell.CodeEnumCastMethod.Aura then
			if fCastTime == 0 then
				strCastInfo = Apollo.GetString("Tooltip_Instant")
			else
				strCastInfo = String_GetWeaselString(Apollo.GetString("Tooltip_CastTime"), tostring(strRound(fCastTime, 2)))
			end
		elseif eCastMethod == Spell.CodeEnumCastMethod.Channeled or eCastMethod == Spell.CodeEnumCastMethod.ChanneledField then
			strCastInfo = String_GetWeaselString(Apollo.GetString("Tooltip_ChannelTime"), tostring(strRound(fCastTime, 2)))
		elseif eCastMethod == Spell.CodeEnumCastMethod.PressHold then
			strCastInfo = String_GetWeaselString(Apollo.GetString("Tooltip_HoldTime"), tostring(strRound(fCastTime, 2)))
		elseif eCastMethod == Spell.CodeEnumCastMethod.ClientSideInteraction then
			strCastInfo = Apollo.GetString("Tooltip_CSI")
		elseif eCastMethod == Spell.CodeEnumCastMethod.RapidTap then
			if fCastTime == 0 then
				strCastInfo = Apollo.GetString("Tooltips_InstantMultiTap")
			else
				strCastInfo = String_GetWeaselString(Apollo.GetString("Tooltips_CastThenMultiTap"), tostring(strRound(fCastTime, 2)))
			end
		elseif eCastMethod == Spell.CodeEnumCastMethod.ChargeRelease then
			strCastInfo = String_GetWeaselString(Apollo.GetString("Tooltips_ChargeTime"), tostring(strRound(fCastTime, 2)))
		else
			strCastInfo = Apollo.GetString("Tooltips_UnknownCastMethod")
		end
	end

	wndCastInfo:SetText(strCastInfo)


	-- Range

	local nMaxRange = splSource:GetMaximumRange()
	local nMinRange = splSource:GetMinimumRange()
	if nMaxRange == 0 then
		wndRange:SetText("")
		wndRange:SetAnchorOffsets(3, 0, -3, 0)
	elseif nMinRange == 0 then
		local strRangeMinMax = String_GetWeaselString(Apollo.GetString("Tooltips_SpellRangeStatic"), Apollo.GetString("CRB_Range_"), nMaxRange, Apollo.GetString("CRB_M_Meters_Symbol"))
		wndRange:SetText(strRangeMinMax)
	else
		local strRangeMinMax = String_GetWeaselString(Apollo.GetString("Tooltips_RangeVariable"), Apollo.GetString("CRB_Range_"), nMinRange, nMaxRange, Apollo.GetString("CRB_M_Meters_Symbol"))
	    wndRange:SetText(strRangeMinMax)
    end


	-- Cost

	local strCost = ""
	local tResource = {}
    local tCosts = splSource:GetCasterInnateCosts()

	if not tCosts or #tCosts == 0 then
		tCosts = splSource:GetCasterInnateRequirements()
	end

	for idx = 1, #tCosts do
		if strCost ~= "" then
			strCost = strCost .. Apollo.GetString("Tooltips_And")
		end

		tResource = tVitals[tCosts[idx].eVital]
		if not tResource then
			tResource = {}
			tResource.strName = String_GetWeaselString(Apollo.GetString("Tooltips_UnknownVital"), tCosts[idx].eVital)
		end

		tResourceData =
		{
			["name"]	= tResource.strName,
			["count"]	= tCosts[idx].nValue,
		}
		strCost = String_GetWeaselString(Apollo.GetString("Tooltips_SpellCost"), strCost, tResourceData)

		if eCastMethod == Spell.CodeEnumCastMethod.Channeled then
			strCost = String_GetWeaselString(Apollo.GetString("Tooltips_ChanneledCost"), strCost)
		elseif eCastMethod == Spell.CodeEnumCastMethod.ChargeRelease then
			strCost = String_GetWeaselString(Apollo.GetString("Tooltips_Charges"), strCost)
		end
	end

	if strCost == "" then
		wndCost:SetAnchorOffsets(3, 0, -3, 0)
	end

	wndCost:SetText(strCost)


	-- Targeting

	if splSource:IsFreeformTarget() then
		wndTargeting:SetText(Apollo.GetString("Tooltips_Freeform"))
	elseif splSource:IsSelfSpell() then
		wndTargeting:SetText(Apollo.GetString("Tooltips_Self"))
	else
		wndTargeting:SetText(Apollo.GetString("Tooltips_Targeted"))
	end


	-- Cooldown / Recharge

    local fCooldownTime = splSource:GetCooldownTime()
    local tCharges = splSource:GetAbilityCharges()

	if fCooldownTime == 0 then
		if tCharges then
			fCooldownTime = tCharges.fRechargeTime
		end

		if fCooldownTime == 0 then
			wndCooldown:SetText(Apollo.GetString("Tooltips_NoCooldown"))
		elseif fCooldownTime < 60 then
			wndCooldown:SetText(String_GetWeaselString(Apollo.GetString("Tooltips_RechargeSeconds"), strRound(fCooldownTime, 0)))
		else
		    wndCooldown:SetText(String_GetWeaselString(Apollo.GetString("Tooltips_RechargeMin"), strRound(fCooldownTime / 60, 1)))
	    end
	elseif fCooldownTime < 60 then
		wndCooldown:SetText(String_GetWeaselString(Apollo.GetString("Tooltips_SecondsCooldown"), strRound(fCooldownTime, 0)))
	else
	    wndCooldown:SetText(String_GetWeaselString(Apollo.GetString("Tooltips_MinCooldown"), strRound(fCooldownTime / 60, 1)))
    end


	-- Mobility

	if (eCastMethod == Spell.CodeEnumCastMethod.Normal or eCastMethod == Spell.CodeEnumCastMethod.RapidTap or eCastMethod == Spell.CodeEnumCastMethod.Multiphase) and fCastTime == 0 then
		wndMobility:SetText("")
		wndMobility:SetAnchorOffsets(3, 0, -3, 0)
	else
		if splSource:IsMovingInterrupted() then
			wndMobility:SetText(Apollo.GetString("Tooltips_Stationary"))
		else
			wndMobility:SetText(Apollo.GetString("Tooltips_Mobile"))
		end
	end


	-- Charges

	if tCharges and tCharges.nChargesMax > 1 then
		tAbilityChargeData =
		{
			["name"] = Apollo.GetString("Tooltips_AbilityCharges"),
			["count"] = tCharges.nChargesMax,
		}
	    wndCharges:SetText(String_GetWeaselString(Apollo.GetString("Tooltips_Tokens"), tAbilityChargeData))
	else
		wndCharges:SetText("")
		wndCharges:SetAnchorOffsets(3, 0, -3, 0)
    end

	-- General Description

	wndGeneralDescription:SetText(splSource:GetFlavor())
	wndGeneralDescription:SetHeightToContentHeight()

	-- Bottom Block

	local wndBottomBlock = wndTooltip:FindChild("BottomDataBlock")
	local wndNextTierString = wndBottomBlock:FindChild("NextTierBonusString")
	local wndTier4String = wndBottomBlock:FindChild("Tier4BonusString")
	local wndTier8String = wndBottomBlock:FindChild("Tier8BonusString")
	local wndRequiredLevel	= wndTooltip:FindChild("RequiredLevelString")

	if tFlags and tFlags.bTiers then
		wndBottomBlock:Show(true)

		-- Tier Bonus Text

		local tTierSpells = AbilityBook.GetAbilityInfo(splSource:GetId(), 0, 0)

		if tTierSpells and tTierSpells.tTiers and tTierSpells.tTiers[1] and tTierSpells.tTiers[5] and tTierSpells.tTiers[8] then
			local nCurrentTier = tTierSpells.nCurrentTier

			wndNextTierString:SetText(tTierSpells.tTiers[1].splObject:GetLasBonusEachTierDesc())
			wndNextTierString:SetHeightToContentHeight()

			wndTier4String:SetText(tTierSpells.tTiers[5].splObject:GetLasTierDesc())
			wndTier4String:SetHeightToContentHeight()
			if nCurrentTier >= 5 then
				wndTier4String:SetTextColor("xkcdMuddyYellow")
			end

			wndTier8String:SetText(tTierSpells.tTiers[9].splObject:GetLasTierDesc())
			wndTier8String:SetHeightToContentHeight()
			if nCurrentTier >= 9 then
				wndTier8String:SetTextColor("xkcdMuddyYellow")
			end
		else
			wndBottomBlock:Show(false)
		end


		-- Required Level

		local nRequiredLevel = splSource:GetRequiredLevel()

		if nRequiredLevel and nRequiredLevel > unitPlayer:GetLevel() then
			wndRequiredLevel:SetText(String_GetWeaselString(Apollo.GetString("Tooltips_ReqLevel"), nRequiredLevel))
			wndRequiredLevel:SetSprite("CRB_Tooltips:sprTooltip_Header")
		else
			wndRequiredLevel:SetText("")
			wndRequiredLevel:SetSprite("")
			--wndTooltip:FindChild("RequiredLevelString"):SetAnchorOffsets(3, 0, -3, 0)
		end
	end

	-- Resize Tooltip
	local nMainLeft, nMainTop, nMainRight, nMainBottom = wndTooltip:GetAnchorOffsets()
	local nBlockLeft, nBlockTop, nBlockRight, nBlockBottom = wndTopDataBlock:GetAnchorOffsets()
	local nLineHeight = wndTopDataBlock:FindChild("CastInfoString"):GetHeight()

	-- Resize name
	local wndTierWidth = Apollo.GetTextWidth("CRB_HeaderSmall", strTier)
	local nNameLeft, nNameTop, nNameRight, nNameBottom = wndName:GetAnchorOffsets()
	wndName:SetAnchorOffsets(nNameLeft, nNameTop, -wndTierWidth, nNameBottom)
	wndName:SetHeightToContentHeight()

	local nLeft = 0
	if wndCost:GetText() == "" then
		nLeft = nLeft + 1
	end
	if wndCharges:GetText() == "" then
		nLeft = nLeft + 1
	end

	local nRight = 0
	if wndRange:GetText() == "" then
		nRight = nRight + 1
	end
	if wndMobility:GetText() == "" then
		nRight = nRight + 1
	end

	if nLeft == 2 and nRight > 0 then
		nMainBottom = nMainBottom - nLineHeight * 2
		nBlockBottom = nBlockBottom - nLineHeight * 2
	elseif nLeft > 0 then
		nMainBottom = nMainBottom - nLineHeight
		nBlockBottom = nBlockBottom - nLineHeight
	end

	nMainBottom = nMainBottom + wndGeneralDescription:GetHeight() + 12

	if not wndBottomBlock:IsVisible() then
		nMainBottom = nMainBottom - wndBottomBlock:GetHeight()
	else
		nMainBottom = nMainBottom + wndNextTierString:GetHeight()
		nMainBottom = nMainBottom + wndTier4String:GetHeight()
		nMainBottom = nMainBottom + wndTier8String:GetHeight()

		--[[if wndTooltip:FindChild("RequiredLevelString"):GetText() == "" then
			nMainBottom = nMainBottom - nLineHeight
		end--]]
	end

	wndTooltip:SetAnchorOffsets(nMainLeft, nMainTop, nMainRight, nMainBottom)
	wndTopDataBlock:SetAnchorOffsets(nBlockLeft, nBlockTop, nBlockRight, nBlockBottom)

	return wndTooltip
end

------------------
-- Buff Tooltip --
------------------

local function GenerateBuffTooltipForm(luaCaller, wndParent, splSource, tFlags)
	-- Initial Bad Data Checks
	if splSource == nil then
		return
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then
		return
	end

	local wndTooltip = wndParent:LoadTooltipForm("ui\\Tooltips\\TooltipsForms.xml", "BuffTooltip_Base", luaCaller)
	wndTooltip:FindChild("NameString"):SetText(splSource:GetName())

    -- Dispellable
	local eSpellClass = splSource:GetClass()
	if eSpellClass == Spell.CodeEnumSpellClass.BuffDispellable or eSpellClass == Spell.CodeEnumSpellClass.DebuffDispellable then
		wndTooltip:FindChild("DispellableString"):SetText(Apollo.GetString("Tooltips_Dispellable"))
	else
		wndTooltip:FindChild("DispellableString"):SetText("")
	end

	-- Calculate width
	local nNameLeft, nNameTop, nNameRight, nNameBottom = wndTooltip:FindChild("NameString"):GetAnchorOffsets()
	local nNameWidth = Apollo.GetTextWidth("CRB_InterfaceLarge", splSource:GetName())
	local nDispelWidth = Apollo.GetTextWidth("CRB_InterfaceMedium", wndTooltip:FindChild("DispellableString"):GetText())
	local nOffset = math.max(0, nNameWidth + nDispelWidth + (nNameLeft * 4) - wndTooltip:FindChild("NameString"):GetWidth())

	-- Resize Tooltip width
	wndTooltip:SetAnchorOffsets(0, 0, wndTooltip:GetWidth() + nOffset, wndTooltip:GetHeight())

	-- General Description
	wndTooltip:FindChild("GeneralDescriptionString"):SetText(wndParent:GetBuffTooltip())
	wndTooltip:FindChild("GeneralDescriptionString"):SetHeightToContentHeight()

	-- Resize tooltip height
	wndTooltip:SetAnchorOffsets(0, 0, wndTooltip:GetWidth(), wndTooltip:GetHeight() + wndTooltip:FindChild("GeneralDescriptionString"):GetHeight())

	return wndTooltip
end

------------------
-- Housing Buff Tooltip --
------------------

local function GenerateHousingBuffTooltipForm(luaCaller, wndParent, splSource, tFlags)
	-- Initial Bad Data Checks
	if splSource == nil then
		return
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then
		return
	end

	local wndTooltip = wndParent:LoadTooltipForm("ui\\Tooltips\\TooltipsForms.xml", "BuffTooltip_Base", luaCaller)
	wndTooltip:FindChild("TopDataBlock:NameString"):SetText(splSource:GetName())

	-- General Description
	wndTooltip:FindChild("GeneralDescriptionString"):SetText(splSource:GetFlavor())
	wndTooltip:FindChild("GeneralDescriptionString"):SetHeightToContentHeight()

	wndTooltip:FindChild("DispellableString"):SetText("")

	-- Resize Tooltip
	wndTooltip:SetAnchorOffsets(0, 0, wndTooltip:GetWidth(), wndTooltip:GetHeight() + wndTooltip:FindChild("GeneralDescriptionString"):GetHeight())

	return wndTooltip
end

function ToolTips:OnUpdateVitals()
	tVitals = Unit.GetVitalTable()
end

function strRound(nSource, nDecimals)
    return tonumber(string.format("%." .. (nDecimals or 0) .. "f", nSource))
end

function ToolTips:HelperCalculateConValue(unitTarget)
	local nUnitCon = GameLib.GetPlayerUnit():GetLevelDifferential(unitTarget)
	local nCon = 1 --default setting

	if nUnitCon <= karConInfo[1][1] then -- lower bound
		nCon = 1
	elseif nUnitCon >= karConInfo[#karConInfo][1] then -- upper bound
		nCon = #karConInfo
	else
		for idx = 2, (#karConInfo-1) do -- everything in between
			if nUnitCon == karConInfo[idx][1] then
				nCon = idx
			end
		end
	end

	return nCon
end

---------------------------------------------------------------------------------------------------
-- WorldTooltipContainer Functions
---------------------------------------------------------------------------------------------------

function ToolTips:CreateCallNames()
	Tooltip.GetItemTooltipForm = GenerateItemTooltipForm
	Tooltip.GetSpellTooltipForm = GenerateSpellTooltipForm
	Tooltip.GetBuffTooltipForm = GenerateBuffTooltipForm
	Tooltip.GetHousingBuffTooltipForm = GenerateHousingBuffTooltipForm
end

function ToolTips:OnGenerateWorldObjectTooltip( wndHandler, wndControl, eToolTipType, unit, strPropName )
	if eToolTipType == Tooltip.TooltipGenerateType_UnitOrProp then
		self:UnitTooltipGen(GameLib.GetWorldTooltipContainer(), unit, strPropName)
	end
end

function ToolTips:OnMouseOverUnitChanged(unit)
	self:UnitTooltipGen(GameLib.GetWorldTooltipContainer(), unit, "")
end

local ToolTipInstance = ToolTips:new()
ToolTipInstance:Init()
