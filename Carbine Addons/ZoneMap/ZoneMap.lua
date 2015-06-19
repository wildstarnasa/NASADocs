-------------------------------------------------------------------------------------------
-- Client Lua Script for ZoneMap
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "QuestLib"
require "Tooltip"
require "XmlDoc"
require "PlayerPathLib"
require "Unit"
require "HexGroups"
require "PublicEventsLib"

local ZoneMap = {}
local knPOIColorHidden 					= 0
local knPOIColorShown 					= 4294967295
local kcrButtonColorNormal 				= CColor.new(0.0, 191/255, 1.0, 1.0)
local kcrButtonColorPressed 			= CColor.new(1.0, 1.0, 1.0, 1.0)
local kcrButtonColorDisabled 			= CColor.new(0.0, 121/255, 121/255, 1.0)
local kcrQuestNumberColor 				= CColor.new(198/255, 255/255, 255/255, 1.0)
local knQuestItemHeight 				= 20
local kstrQuestFont 					= "CRB_InterfaceMedium_B"
local kstrQuestNameColor 				= "ffffffff"
local kstrQuestNameColorComplete 		= "ff2fdc02"
local kstrQuestNameColorTimed 			= "fffffc00"
local kcrEpisodeColor 					= "ff31fcf6"
local kcrEpisodeColorMinimized 			= "cc21a5a1"

local ktHexColor =
{
	tPath 			= { crBorder = CColor.new(1, 153/255, 0, 1),	crInterior = CColor.new(1, 190/255, 0, 0.4) },
	tQuest 			= { crBorder = CColor.new(1, 1, 0, 1),			crInterior = CColor.new(1, 1, 0, 0.4) },
	tChallenge 		= { crBorder = CColor.new(153/255, 0, 1, 1),	crInterior = CColor.new(153/255, 0, 1, 0.4) },
	tPublicEvent 	= { crBorder = CColor.new(0, 1, 0, 1),			crInterior = CColor.new(0, 1, 0, 0.4) },
	tNemesisRgn		= { crBorder = CColor.new(1, 1, 1, 1),			crInterior = CColor.new(1, 1, 1, 0.4) }
}

local ktMarkerCategories =
{
	QuestNPCs 			= 1,
	TrackedQuests 		= 2,
	Missions 			= 3,
	Challenges 			= 4,
	PublicEvents 		= 5,
	Tradeskills 		= 6,
	Vendors 			= 7,
	Services 			= 8,
	Portals 			= 9,
	BindPoints 			= 10,
	GroupObjectives 	= 11,
	MiningNodes 		= 12,
	RelicNodes 			= 13,
	SurvivalistNodes 	= 14,
	FarmingNodes 		= 15,
	NemesisRegions 		= 16,
	Taxis 				= 17,
	CityDirections 		= 18,
}

local karCityDirectionsTypeToIcon =
{
	[GameLib.CityDirectionType.Mailbox] 		= "ClientSprites:Icon_Windows_UI_ReadMail",
	[GameLib.CityDirectionType.Bank] 			= "ClientSprites:Icon_BuffDebuff_Money_Loot_Drop_Increase_Buff",
	[GameLib.CityDirectionType.AuctionHouse] 	= "ClientSprites:Icon_Windows_UI_CRB_LevelUp_NewCapitalCity",
	[GameLib.CityDirectionType.CommodityMarket] = "ClientSprites:Icon_Windows_UI_CRB_LevelUp_NewCapitalCity",
	[GameLib.CityDirectionType.AbilityVendor] 	= "ClientSprites:Icon_Windows_UI_CRB_LevelUp_NewAbility",
	[GameLib.CityDirectionType.Tradeskill] 		= "ClientSprites:Icon_Windows_UI_CRB_LevelUp_NewGearSlot",
	[GameLib.CityDirectionType.General] 		= "ClientSprites:Icon_Windows_UI_CRB_LevelUp_NewGeneralFeature",
	[GameLib.CityDirectionType.HousingNpc] 		= "ClientSprites:Icon_Windows_UI_CRB_LevelUp_NewCapitalCity",
	[GameLib.CityDirectionType.Transport] 		= "ClientSprites:Icon_Windows_UI_CRB_LevelUp_NewZone",
}

local ktGlobalPortalInfo =
{
	-- Dungeons
	Stormtalon					= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapDungeon_Stormtalon,				worldLocIds = { 12676 } },
	KelVoreth					= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapDungeon_KelVoreth,					worldLocIds = { 24997 } },
	Skullcano					= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapDungeon_Skullcano,					worldLocIds = { 25038 } },
	SwordMaiden					= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapDungeon_SwordMaiden,				worldLocIds = { 32913 } },
	UltimateProtogames			= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapDungeon_UltimateProtogames,		worldLocIds = { 48584 } },
	ProtogamesAcademyExile		= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapDungeon_ProtogamesAcademyExile,	worldLocIds = { 48518, 48519 },	idZones = { GameLib.MapZone.Algoroc, GameLib.MapZone.Celestion } },
	ProtogamesAcademyDominion	= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapDungeon_ProtogamesAcademyDominion,	worldLocIds = { 48532, 48533 },	idZones = { GameLib.MapZone.Ellevar, GameLib.MapZone.Deradune } },

	-- Adventures
	Hycrest						= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapAdventure_Hycrest,					worldLocIds = { 41211 } },
	Astrovoid					= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapAdventure_Astrovoid,				worldLocIds = { 38344 } },
	NorthernWilds				= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapAdventure_NorthernWilds,			worldLocIds = { 38354 } },
	Galeras						= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapAdventure_Galeras,					worldLocIds = { 38355 } },
	Whitevale					= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapAdventure_Whitevale,				worldLocIds = { 41168 } },
	Malgrave					= { unlockEnumId = GameLib.LevelUpUnlock.WorldMapAdventure_Malgrave,				worldLocIds = { 41717 } }
}

local ktConColors =
{
	[Unit.CodeEnumLevelDifferentialAttribute.Grey] 		= "ff9aaea3",
	[Unit.CodeEnumLevelDifferentialAttribute.Green] 	= "ff37ff00",
	[Unit.CodeEnumLevelDifferentialAttribute.Cyan] 		= "ff46ffff",
	[Unit.CodeEnumLevelDifferentialAttribute.Blue] 		= "ff3052fc",
	[Unit.CodeEnumLevelDifferentialAttribute.White] 	= "ffffffff",
	[Unit.CodeEnumLevelDifferentialAttribute.Yellow] 	= "ffffd400",
	[Unit.CodeEnumLevelDifferentialAttribute.Orange] 	= "ffff6a00",
	[Unit.CodeEnumLevelDifferentialAttribute.Red] 		= "ffff0000",
	[Unit.CodeEnumLevelDifferentialAttribute.Magenta] 	= "fffb00ff",
}

-- TODO: Distinguish markers for different nodes from each other
local kstrMiningNodeIcon 	= "IconSprites:Icon_MapNode_Map_Node_Mining"
local kstrRelicNodeIcon 	= "IconSprites:Icon_MapNode_Map_Node_Relic"
local kstrFarmingNodeIcon 	= "IconSprites:Icon_MapNode_Map_Node_Plant"
local kstrSurvivalNodeIcon 	= "IconSprites:Icon_MapNode_Map_Node_Tree"
local kstrFishingNodeIcon 	= "IconSprites:Icon_MapNode_Map_Node_Fishing"

local knSaveVersion = 4

-- ** Add new object types here ** --
function ZoneMap:CreateOverlayObjectTypes()
	-- Tooltip draw order is based on the order of these values.  If we want it to change, the order that we create the overlays needs to change.
	self.eObjectTypeQuest				= self.wndZoneMap:CreateOverlayType(ktHexColor.tQuest.crBorder, ktHexColor.tQuest.crInterior, "CRB_MegamapSprites:sprMap_QuestMarker", "CRB_MegamapSprites:sprMap_QuestMarkerLit")
	self.eObjectTypeChallenge			= self.wndZoneMap:CreateOverlayType(ktHexColor.tChallenge.crBorder, ktHexColor.tChallenge.crInterior, "sprChallengeTypeGenericLarge", "sprChallengeTypeGenericLarge")
	self.eObjectTypePublicEvent			= self.wndZoneMap:CreateOverlayType(ktHexColor.tPublicEvent.crBorder, ktHexColor.tPublicEvent.crInterior, "sprMM_POI", "sprMM_POI")
	-- path mission icons will be set in ToggleWindow
	self.eObjectTypeMission				= self.wndZoneMap:CreateOverlayType(ktHexColor.tPath.crBorder, ktHexColor.tPath.crInterior, "", "")
	self.eObjectTypeNemesisRegion		= self.wndZoneMap:CreateOverlayType(ktHexColor.tNemesisRgn.crBorder, ktHexColor.tNemesisRgn.crInterior, "", "")
	self.eObjectTypeLocation			= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeHexGroup			= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeMapTrackedUnit		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeCityDirectionPing	= self.wndZoneMap:CreateOverlayType()

	-- units
	self.eObjectTypeQuestReward 		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeQuestReceiving 		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeQuestNew 			= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeQuestNewTradeskill	= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeQuestNewSoon 		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeTradeskills 		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeVendor 				= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeAuctioneer 			= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeCommodity 			= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeInstancePortal 		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeBindPointActive 	= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeBindPointInactive 	= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeMiningNode 			= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeRelicHunterNode 	= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeSurvivalistNode 	= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeFarmingNode 		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeFishingNode 		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeHazard 				= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeVendorFlight 		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeFriend				= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeRival				= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeTrainer				= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeQuestKill			= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeQuestTarget			= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypePublicEventKill		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypePublicEventTarget	= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeVendorFlightPathNew	= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeNeutral				= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeHostile				= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeGroupMember			= self.wndZoneMap:CreateOverlayType()
	self.eObjectCityDirections			= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeCREDDExchange		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeCostume				= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeBank				= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeGuildBank			= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeGuildRegistrar		= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeMail				= self.wndZoneMap:CreateOverlayType()
	self.eObjectTypeConvert				= self.wndZoneMap:CreateOverlayType()
end

function ZoneMap:CreatePOIIcons()
	self.tPOITypes =
	{
		--tChallengeFlash 	= {strSprite = "Icon_MapNode_Map_Generic_POI",				strType = Apollo.GetString("ZoneMap_ChallengeLocation")}, -- TODO
		[self.eObjectTypeQuest]					= {strSprite = "",												eCategory = ktMarkerCategories.TrackedQuests,		strType = Apollo.GetString("MiniMap_QuestObjectives")},
		[self.eObjectTypeChallenge]				= {strSprite = "Icon_MapNode_Map_Generic_POI",					eCategory = ktMarkerCategories.Challenges,			strType = Apollo.GetString("CBCrafting_Challenge")}, -- TODO
		[self.eObjectTypePublicEvent] 			= {strSprite = "sprMap_IconCompletion_Challenge",				eCategory = ktMarkerCategories.PublicEvents,		strType = Apollo.GetString("ZoneMap_PublicEvent")}, -- TODO
		-- Mission sprites will be set up in ToggleWindow	
		[self.eObjectTypeMission] 				= {strSprite = "",												eCategory = ktMarkerCategories.Missions,			strType = ""},
		[self.eObjectTypeNemesisRegion]			= {strSprite = "",												eCategory = ktMarkerCategories.NemesisRegions,		strType = Apollo.GetString("ZoneMap_NemesisRegions")},
		[self.eObjectTypeLocation]				= {strSprite = "",												eCategory = nil,									strType = ""},
		[self.eObjectTypeHexGroup]				= {strSprite = "",												eCategory = nil,									strType = ""},
		[self.eObjectTypeMapTrackedUnit]		= {strSprite = "",												eCategory = nil,									strType = ""},
		[self.eObjectTypeCityDirectionPing]	= {strSprite = "",													eCategory = nil,									strType = ""},
		[self.eObjectTypeQuestReward] 			= {strSprite = "sprMM_QuestCompleteUntracked",					eCategory = ktMarkerCategories.QuestNPCs,			strType = Apollo.GetString("ZoneMap_QuestRedeemer")},
		[self.eObjectTypeQuestReceiving]		= {strSprite = "sprMM_QuestCompleteUntracked",					eCategory = ktMarkerCategories.QuestNPCs,			strType = Apollo.GetString("ZoneMap_QuestRedeemer")},
		[self.eObjectTypeQuestNew] 				= {strSprite = "Icon_MapNode_Map_Quest",						eCategory = ktMarkerCategories.QuestNPCs,			strType = Apollo.GetString("ZoneMap_QuestGiver")},
		[self.eObjectTypeQuestNewTradeskill]	= {strSprite = "",												eCategory = ktMarkerCategories.QuestNPCs,			strType = Apollo.GetString("ZoneMap_QuestGiver")},
		[self.eObjectTypeQuestNewSoon] 			= {strSprite = "Icon_MapNode_Map_Quest_Disabled", 				eCategory = ktMarkerCategories.QuestNPCs,			strType = Apollo.GetString("ZoneMap_QuestGiver")},
		[self.eObjectTypeTradeskills]			= {strSprite = "IconSprites:Icon_MapNode_Map_Tradeskill",		eCategory = ktMarkerCategories.Tradeskills,			strType = Apollo.GetString("ZoneMap_TradeskillPOI")},
		[self.eObjectTypeVendor] 				= {strSprite = "Icon_MapNode_Map_Vendor",						eCategory = ktMarkerCategories.Vendors,				strType = Apollo.GetString("CRB_Vendor")},
		[self.eObjectTypeAuctioneer]			= {strSprite = "",												eCategory = ktMarkerCategories.Services,			strType = Apollo.GetString("MarketplaceAuction_AuctionHouse")},
		[self.eObjectTypeCommodity]				= {strSprite = "",												eCategory = ktMarkerCategories.Services,			strType = Apollo.GetString("MarketplaceCommodity_CommoditiesExchange")},
		[self.eObjectTypeInstancePortal] 		= {strSprite = "Icon_MapNode_Map_Portal",						eCategory = ktMarkerCategories.Portals,				strType = Apollo.GetString("ZoneMap_InstancePortal")}, -- TODO
		[self.eObjectTypeBindPointActive] 		= {strSprite = "Icon_MapNode_Map_Gate",							eCategory = ktMarkerCategories.BindPoints,			strType = Apollo.GetString("ZoneMap_CurrentBindPoint")},
		[self.eObjectTypeBindPointInactive] 	= {strSprite = "Icon_MapNode_Map_Gate",							eCategory = ktMarkerCategories.BindPoints,			strType = Apollo.GetString("ZoneMap_AvailableBindPoint")},
		[self.eObjectTypeMiningNode]			= {strSprite = "",												eCategory = ktMarkerCategories.MiningNodes,			strType = Apollo.GetString("ZoneMap_MiningNodes")},
		[self.eObjectTypeRelicHunterNode]		= {strSprite = "",												eCategory = ktMarkerCategories.RelicNodes,			strType = Apollo.GetString("ZoneMap_RelicHunterNodes")},
		[self.eObjectTypeSurvivalistNode]		= {strSprite = "",												eCategory = ktMarkerCategories.SurvivalistNodes,	strType = Apollo.GetString("ZoneMap_SurvivalistNodes")},
		[self.eObjectTypeFarmingNode]			= {strSprite = "",												eCategory = ktMarkerCategories.FarmingNodes,		strType = Apollo.GetString("ZoneMap_FarmingNodes")},
		[self.eObjectTypeFishingNode]			= {strSprite = "",												eCategory = nil,									strType = ""},
		[self.eObjectTypeHazard]				= {strSprite = "",												eCategory = nil,									strType = ""},
		[self.eObjectTypeVendorFlight]			= {strSprite = "",												eCategory = ktMarkerCategories.Taxis,				strType = Apollo.GetString("ZoneMap_Taxis")},
		[self.eObjectTypeFriend]				= {strSprite = "",												eCategory = nil,									strType = Apollo.GetString("MiniMap_Friends")},
		[self.eObjectTypeRival]					= {strSprite = "",												eCategory = nil,									strType = Apollo.GetString("MiniMap_Rivals")},
		[self.eObjectTypeTrainer]				= {strSprite = "",												eCategory = nil,									strType = Apollo.GetString("ZoneMap_Trainer")},
		[self.eObjectTypeQuestKill]				= {strSprite = "",												eCategory = nil,									strType = ""},
		[self.eObjectTypeQuestTarget]			= {strSprite = "",												eCategory = ktMarkerCategories.QuestNPCs,			strType = ""},
		[self.eObjectTypePublicEventKill]		= {strSprite = "",												eCategory = nil,									strType = ""},
		[self.eObjectTypePublicEventTarget]		= {strSprite = "",												eCategory = nil,									strType = ""},
		[self.eObjectTypeVendorFlightPathNew]	= {strSprite = "",												eCategory = ktMarkerCategories.Taxis,				strType = Apollo.GetString("ZoneMap_Taxis")},
		[self.eObjectTypeNeutral]				= {strSprite = "",												eCategory = nil,									strType = ""},
		[self.eObjectTypeHostile]				= {strSprite = "",												eCategory = nil,									strType = ""},
		[self.eObjectTypeGroupMember]			= {strSprite = "",												eCategory = nil,									strType = Apollo.GetString("MiniMap_GroupMembers")},
		[self.eObjectCityDirections]			= {strSprite = "Icon_MapNode_Map_CityDirections",				eCategory = ktMarkerCategories.CityDirections,		strType = Apollo.GetString("ZoneMap_CityDirections")},
		[self.eObjectTypeCREDDExchange]			= {strSprite = "",												eCategory = ktMarkerCategories.Services,			strType = Apollo.GetString("MarketplaceCredd_Title")},
		[self.eObjectTypeCostume]				= {strSprite = "",												eCategory = ktMarkerCategories.Services,			strType = Apollo.GetString("ZoneMap_CostumeAndDyes")},
		[self.eObjectTypeBank]					= {strSprite = "",												eCategory = ktMarkerCategories.Services,			strType = Apollo.GetString("Bank_Header")},
		[self.eObjectTypeGuildBank]				= {strSprite = "",												eCategory = ktMarkerCategories.Services,			strType = Apollo.GetString("GuildBank_Title")},
		[self.eObjectTypeGuildRegistrar]		= {strSprite = "",												eCategory = ktMarkerCategories.Services,			strType = Apollo.GetString("DialogResponse_GuildRegistrar")},
		[self.eObjectTypeMail]					= {strSprite = "",												eCategory = ktMarkerCategories.Services,			strType = Apollo.GetString("InterfaceMenu_Mail")},
		[self.eObjectTypeConvert]				= {strSprite = "",												eCategory = ktMarkerCategories.Services,			strType = Apollo.GetString("ResourceConversion_Title")},
	}
end

-- Helper function, new unit types should be added to this list too
function ZoneMap:GetAllUnitTypes()
	local tUnitTypes =
	{
		self.eObjectTypeQuestReward,
		self.eObjectTypeQuestReceiving,
		self.eObjectTypeQuestNew,
		self.eObjectTypeQuestNewSoon,
		self.eObjectTypeTradeskills,
		self.eObjectTypeVendor,
		self.eObjectTypeAuctioneer,
		self.eObjectTypeCommodity,
		self.eObjectTypeInstancePortal,
		self.eObjectTypeBindPointActive,
		self.eObjectTypeBindPointInactive,
		self.eObjectTypeMiningNode,
		self.eObjectTypeRelicHunterNode,
		self.eObjectTypeSurvivalistNode,
		self.eObjectTypeFarmingNode,
		self.eObjectTypeFishingNode,
		self.eObjectTypeHazard,
		self.eObjectTypeVendorFlight,
		self.eObjectTypeFriend,
		self.eObjectTypeRival,
		self.eObjectTypeTrainer,
		self.eObjectTypeQuestKill,
		self.eObjectTypeQuestTarget,
		self.eObjectTypePublicEventKill,
		self.eObjectTypePublicEventTarget,
		self.eObjectTypeVendorFlightPathNew,
		self.eObjectTypeNeutral,
		self.eObjectTypeHostile,
		self.eObjectTypeGroupMember,
		self.eObjectCityDirections,
		self.eObjectTypeCREDDExchange,
		self.eObjectTypeCostume,
		self.eObjectTypeBank,
		self.eObjectTypeGuildBank,
		self.eObjectTypeGuildRegistrar,
		self.eObjectTypeMail,
		self.eObjectTypeConvert,
		self.eObjectTypeQuestNewTradeskill,
	}

	return tUnitTypes
end

function ZoneMap:BuildCustomMarkerInfo()
	self.tMinimapMarkerInfo =
	{
		IronNode					= { nOrder = 100, 	objectType = self.eObjectTypeMiningNode, 		strIcon = kstrMiningNodeIcon, 	crObject = kcrMiningNode, 	crEdge = kcrMiningNode },
		TitaniumNode				= { nOrder = 100, 	objectType = self.eObjectTypeMiningNode, 		strIcon = kstrMiningNodeIcon, 	crObject = kcrMiningNode, 	crEdge = kcrMiningNode },
		ZephyriteNode				= { nOrder = 100, 	objectType = self.eObjectTypeMiningNode, 		strIcon = kstrMiningNodeIcon, 	crObject = kcrMiningNode, 	crEdge = kcrMiningNode },
		PlatinumNode				= { nOrder = 100, 	objectType = self.eObjectTypeMiningNode, 		strIcon = kstrMiningNodeIcon, 	crObject = kcrMiningNode, 	crEdge = kcrMiningNode },
		HydrogemNode				= { nOrder = 100, 	objectType = self.eObjectTypeMiningNode, 		strIcon = kstrMiningNodeIcon, 	crObject = kcrMiningNode, 	crEdge = kcrMiningNode },
		XenociteNode				= { nOrder = 100, 	objectType = self.eObjectTypeMiningNode, 		strIcon = kstrMiningNodeIcon, 	crObject = kcrMiningNode, 	crEdge = kcrMiningNode },
		ShadeslateNode				= { nOrder = 100, 	objectType = self.eObjectTypeMiningNode, 		strIcon = kstrMiningNodeIcon, 	crObject = kcrMiningNode, 	crEdge = kcrMiningNode },
		GalactiumNode				= { nOrder = 100, 	objectType = self.eObjectTypeMiningNode, 		strIcon = kstrMiningNodeIcon, 	crObject = kcrMiningNode, 	crEdge = kcrMiningNode },
		NovaciteNode				= { nOrder = 100, 	objectType = self.eObjectTypeMiningNode, 		strIcon = kstrMiningNodeIcon, 	crObject = kcrMiningNode, 	crEdge = kcrMiningNode },
		StandardRelicNode			= { nOrder = 100, 	objectType = self.eObjectTypeRelicHunterNode, 	strIcon = kstrRelicNodeIcon, 	crObject = kcrRelicNode, 	crEdge = kcrRelicNode },
		AcceleratedRelicNode		= { nOrder = 100, 	objectType = self.eObjectTypeRelicHunterNode, 	strIcon = kstrRelicNodeIcon, 	crObject = kcrRelicNode, 	crEdge = kcrRelicNode },
		AdvancedRelicNode			= { nOrder = 100, 	objectType = self.eObjectTypeRelicHunterNode, 	strIcon = kstrRelicNodeIcon, 	crObject = kcrRelicNode, 	crEdge = kcrRelicNode },
		DynamicRelicNode			= { nOrder = 100, 	objectType = self.eObjectTypeRelicHunterNode, 	strIcon = kstrRelicNodeIcon, 	crObject = kcrRelicNode, 	crEdge = kcrRelicNode },
		KineticRelicNode			= { nOrder = 100, 	objectType = self.eObjectTypeRelicHunterNode, 	strIcon = kstrRelicNodeIcon, 	crObject = kcrRelicNode, 	crEdge = kcrRelicNode },
		SpirovineNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		BladeleafNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		YellowbellNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		PummelgranateNode			= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		SerpentlilyNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		GoldleafNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		HoneywheatNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		CrowncornNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		CoralscaleNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		LogicleafNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		StoutrootNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		GlowmelonNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		FaerybloomNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		WitherwoodNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		FlamefrondNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		GrimgourdNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		MourningstarNode			= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		BloodbriarNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		OctopodNode					= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		HeartichokeNode				= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		SmlGrowthshroomNode			= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		MedGrowthshroomNode			= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		LrgGrowthshroomNode			= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		SmlHarvestshroomNode		= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		MedHarvestshroomNode		= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		LrgHarvestshroomNode		= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode,		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		SmlRenewshroomNode			= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode, 		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		MedRenewshroomNode			= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode,		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		LrgRenewshroomNode			= { nOrder = 100, 	objectType = self.eObjectTypeFarmingNode,		strIcon = kstrFarmingNodeIcon, 	crObject = kcrFarmingNode, 	crEdge = kcrFarmingNode },
		AlgorocTreeNode				= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		CelestionTreeNode			= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon,	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		DeraduneTreeNode			= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		EllevarTreeNode				= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon,	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		GalerasTreeNode				= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		AuroriaTreeNode				= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		WhitevaleTreeNode			= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		DreadmoorTreeNode			= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		FarsideTreeNode				= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		CoralusTreeNode				= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		MurkmireTreeNode			= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		WilderrunTreeNode			= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		MalgraveTreeNode			= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		HalonRingTreeNode			= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		GrimvaultTreeNode			= { nOrder = 100, 	objectType = self.eObjectTypeSurvivalistNode,	strIcon = kstrSurvivalNodeIcon, 	crObject = kcrSurvivalNode, 	crEdge = kcrSurvivalNode },
		SchoolOfFishNode			= { nOrder = 100, 	objectType = self.eObjectTypeFishingNode,		strIcon = kstrFishingNodeIcon,  	crObject = kcrFishingNode, 	crEdge = kcrFishingNode },
		Friend						= { nOrder = 2, 	objectType = self.eObjectTypeFriend, 			strIcon = "IconSprites:Icon_Windows_UI_CRB_Friend",			bNeverShowOnEdge = true, bShown, bFixedSizeMedium = true },
		Rival						= { nOrder = 3, 	objectType = self.eObjectTypeRival, 			strIcon = "IconSprites:Icon_MapNode_Map_Rival", 			bNeverShowOnEdge = true, bShown, bFixedSizeSmall = true },
		Trainer						= { nOrder = 4, 	objectType = self.eObjectTypeTrainer, 			strIcon = "IconSprites:Icon_MapNode_Map_Trainer", 			bNeverShowOnEdge = true, bFixedSizeMedium = true },
		QuestKill					= { nOrder = 5, 	objectType = self.eObjectTypeQuestKill, 		strIcon = "sprMM_TargetCreature", 					bNeverShowOnEdge = true, bFixedSizeMedium = true },
		QuestTarget					= { nOrder = 6,		objectType = self.eObjectTypeQuestTarget, 		strIcon = "sprMM_TargetObjective", 					bNeverShowOnEdge = true, bFixedSizeMedium = true },
		PublicEventKill				= { nOrder = 7,		objectType = self.eObjectTypePublicEventKill, 	strIcon = "sprMM_TargetCreature", 					bNeverShowOnEdge = true, bFixedSizeMedium = true },
		PublicEventTarget			= { nOrder = 8,		objectType = self.eObjectTypePublicEventTarget, strIcon = "sprMM_TargetObjective", 					bNeverShowOnEdge = true, bFixedSizeMedium = true },
		QuestReward					= { nOrder = 9,		objectType = self.eObjectTypeQuestReward, 		strIcon = "sprMM_QuestCompleteUntracked", 				bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestRewardSoldier			= { nOrder = 10,	objectType = self.eObjectTypeQuestReward, 		strIcon = "IconSprites:Icon_MapNode_Map_Soldier_Accepted", 	bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestRewardSettler			= { nOrder = 11,	objectType = self.eObjectTypeQuestReward, 		strIcon = "IconSprites:Icon_MapNode_Map_Settler_Accepted", 	bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestRewardScientist		= { nOrder = 12,	objectType = self.eObjectTypeQuestReward, 		strIcon = "IconSprites:Icon_MapNode_Map_Scientist_Accepted", 	bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestRewardExplorer			= { nOrder = 13,	objectType = self.eObjectTypeQuestReward, 		strIcon = "IconSprites:Icon_MapNode_Map_Explorer_Accepted", 	bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewDaily				= { nOrder = 14,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Quest", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNew					= { nOrder = 14,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Quest", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewTradeskill			= { nOrder = 14,	objectType = self.eObjectTypeQuestNewTradeskill, 	strIcon = "IconSprites:Icon_MapNode_Map_Quest_Tradeskill", 	bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestGivingTradeskill		= { nOrder = 14,	objectType = self.eObjectTypeQuestNewTradeskill, 	strIcon = "IconSprites:Icon_MapNode_Map_Quest_Tradeskill", 	bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestReceivingTradeskill 	= { nOrder = 14,	objectType = self.eObjectTypeQuestNewTradeskill, 	strIcon = "IconSprites:Icon_MapNode_Map_Quest_Tradeskill", 	bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewSoldier				= { nOrder = 15,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Soldier", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewSettler				= { nOrder = 16,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Settler", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewScientist			= { nOrder = 17,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Scientist", 		bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewExplorer			= { nOrder = 18,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Explorer", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewMain				= { nOrder = 19,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Quest", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewMainSoldier			= { nOrder = 20,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Soldier", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewMainSettler			= { nOrder = 21,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Settler", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewMainScientist		= { nOrder = 22,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Scientist", 		bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewMainExplorer		= { nOrder = 23,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Explorer", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewRepeatable			= { nOrder = 24,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Quest", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewRepeatableSoldier 	= { nOrder = 25,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Soldier", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewRepeatableSettler 	= { nOrder = 26,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Settler", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewRepeatableScientist	= { nOrder = 27,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Scientist",			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewRepeatableExplorer	= { nOrder = 28,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Explorer", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestReceiving				= { nOrder = 29,	objectType = self.eObjectTypeQuestReceiving, 	strIcon = "sprMM_QuestCompleteOngoing", 				bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestReceivingSoldier		= { nOrder = 30,	objectType = self.eObjectTypeQuestReceiving, 	strIcon = "IconSprites:Icon_MapNode_Map_Soldier", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestReceivingSettler		= { nOrder = 31,	objectType = self.eObjectTypeQuestReceiving, 	strIcon = "IconSprites:Icon_MapNode_Map_Settler", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestReceivingScientist		= { nOrder = 32,	objectType = self.eObjectTypeQuestReceiving, 	strIcon = "IconSprites:Icon_MapNode_Map_Scientist", 		bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestReceivingExplorer		= { nOrder = 33,	objectType = self.eObjectTypeQuestReceiving, 	strIcon = "IconSprites:Icon_MapNode_Map_Explorer", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewSoon				= { nOrder = 34,	objectType = self.eObjectTypeQuestNewSoon, 		strIcon = "IconSprites:Icon_MapNode_Map_Quest_Disabled", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		QuestNewMainSoon			= { nOrder = 35,	objectType = self.eObjectTypeQuestNewSoon, 		strIcon = "IconSprites:Icon_MapNode_Map_Quest_Disabled", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		ConvertItem					= { nOrder = 36,	objectType = self.eObjectTypeConvert, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_ResourceConversion", 	bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		ConvertRep					= { nOrder = 37,	objectType = self.eObjectTypeConvert, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Reputation", 		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		Vendor						= { nOrder = 38,	objectType = self.eObjectTypeVendor, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor", 			bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		Mail						= { nOrder = 39,	objectType = self.eObjectTypeMail, 				strIcon = "IconSprites:Icon_MapNode_Map_Mailbox", 			bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		CityDirections				= { nOrder = 40,	objectType = self.eObjectCityDirections, 		strIcon = "IconSprites:Icon_MapNode_Map_CityDirections", 		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		Dye							= { nOrder = 41,	objectType = self.eObjectTypeCostume, 			strIcon = "IconSprites:Icon_MapNode_Map_DyeSpecialist", 		bNeverShowOnEdge = true, bFixedSizeMedium = true },
		FlightPathSettler			= { nOrder = 42,	objectType = self.eObjectTypeVendorFlight, 		strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Flight", 		bNeverShowOnEdge = true, bFixedSizeMedium = true },
		FlightPath					= { nOrder = 43,	objectType = self.eObjectTypeVendorFlightPathNew,			strIcon = "IconSprites:Icon_MapNode_Map_Taxi", 			bNeverShowOnEdge = true, bFixedSizeMedium = true },
		FlightPathNew				= { nOrder = 44,	objectType = self.eObjectTypeVendorFlight, 		strIcon = "IconSprites:Icon_MapNode_Map_Taxi_Undiscovered", 	bNeverShowOnEdge = true, bFixedSizeMedium = true },
		TalkTo						= { nOrder = 45,	objectType = self.eObjectTypeQuestTarget, 		strIcon = "IconSprites:Icon_MapNode_Map_Chat", 			bNeverShowOnEdge = true, bFixedSizeMedium = true },
		InstancePortal				= { nOrder = 46,	objectType = self.eObjectTypeInstancePortal, 	strIcon = "IconSprites:Icon_MapNode_Map_Portal", 			bNeverShowOnEdge = true },
		BindPoint					= { nOrder = 47,	objectType = self.eObjectTypeBindPointInactive, strIcon = "IconSprites:Icon_MapNode_Map_Gate", 			bNeverShowOnEdge = true },
		BindPointCurrent			= { nOrder = 48,	objectType = self.eObjectTypeBindPointActive, 	strIcon = "IconSprites:Icon_MapNode_Map_Gate", 			bNeverShowOnEdge = true },
		TradeskillTrainer			= { nOrder = 49,	objectType = self.eObjectTypeTradeskills, 		strIcon = "IconSprites:Icon_MapNode_Map_Tradeskill", 		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		CraftingStation				= { nOrder = 50,	objectType = self.eObjectTypeTradeskills, 		strIcon = "IconSprites:Icon_MapNode_Map_Tradeskill", 		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		CommodityMarketplace		= { nOrder = 51,	objectType = self.eObjectTypeCommodity, 		strIcon = "IconSprites:Icon_MapNode_Map_CommoditiesExchange",	bNeverShowOnEdge = true, bHideIfHostile = true },
		ItemAuctionhouse			= { nOrder = 52,	objectType = self.eObjectTypeAuctioneer, 		strIcon = "IconSprites:Icon_MapNode_Map_AuctionHouse", 		bNeverShowOnEdge = true, bHideIfHostile = true },
		SettlerImprovement			= { nOrder = 53,	objectType = GameLib.CodeEnumMapOverlayType.PathObjective, strIcon = "CRB_MinimapSprites:sprMM_SmallIconSettler", 	bNeverShowOnEdge = true },
		CREDDExchange				= { nOrder = 54,	objectType = self.eObjectTypeCREDDExchange, 	strIcon = "IconSprites:Icon_MapNode_Map_CREED", 			bNeverShowOnEdge = true, bHideIfHostile = true },
		GroupMember					= { nOrder = 1,		objectType = self.eObjectTypeGroupMember, 		strIcon = "IconSprites:Icon_MapNode_Map_GroupMember", 		bFixedSizeLarge = true },
		Bank						= { nOrder = 54,	objectType = self.eObjectTypeBank, 				strIcon = "IconSprites:Icon_MapNode_Map_Bank", 			bNeverShowOnEdge = true, bFixedSizeLarge = true, bHideIfHostile = true },
		GuildBank					= { nOrder = 56,	objectType = self.eObjectTypeGuildBank, 		strIcon = "IconSprites:Icon_MapNode_Map_Bank", 			bNeverShowOnEdge = true, bFixedSizeLarge = true, crObject = ApolloColor.new("yellow"), bHideIfHostile = true },
		GuildRegistrar				= { nOrder = 55,	objectType = self.eObjectTypeGuildRegistrar, 	strIcon = "CRB_MinimapSprites:sprMM_Group",				bNeverShowOnEdge = true, bFixedSizeLarge = true, crObject = ApolloColor.new("yellow"), bHideIfHostile = true },
		VendorGeneral				= { nOrder = 38,	objectType = self.eObjectTypeVendor,			strIcon = "IconSprites:Icon_MapNode_Map_Vendor",			bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorArmor					= { nOrder = 38,	objectType = self.eObjectTypeVendor, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Armor",		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorConsumable			= { nOrder = 38,	objectType = self.eObjectTypeVendor, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Consumable",	bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorElderGem				= { nOrder = 38,	objectType = self.eObjectTypeVendor, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_ElderGem",		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorHousing				= { nOrder = 38,	objectType = self.eObjectTypeVendor, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Housing",		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorMount					= { nOrder = 38,	objectType = self.eObjectTypeVendor, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Mount",		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorRenown				= { nOrder = 38,	objectType = self.eObjectTypeVendor, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Renown",		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorReputation			= { nOrder = 38,	objectType = self.eObjectTypeVendor, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Reputation",	bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorResourceConversion	= { nOrder = 38,	objectType = self.eObjectTypeVendor, 			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_ResourceConversion",	bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorTradeskill			= { nOrder = 38,	objectType = self.eObjectTypeVendor,			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Tradeskill",	bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorWeapon				= { nOrder = 38,	objectType = self.eObjectTypeVendor,			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Weapon",		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorPvPArena				= { nOrder = 38,	objectType = self.eObjectTypeVendor,			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Prestige_Arena",	bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorPvPBattlegrounds		= { nOrder = 38,	objectType = self.eObjectTypeVendor,			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Prestige_Battlegrounds",	bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		VendorPvPWarplots			= { nOrder = 38,	objectType = self.eObjectTypeVendor,			strIcon = "IconSprites:Icon_MapNode_Map_Vendor_Prestige_Warplot",		bNeverShowOnEdge = true, bFixedSizeMedium = true, bHideIfHostile = true },
		ContractBoard				= { nOrder = 14,	objectType = self.eObjectTypeQuestNew, 			strIcon = "IconSprites:Icon_MapNode_Map_Contracts", 		bNeverShowOnEdge = true, bHideIfHostile = true },
	}
end

function ZoneMap:BuildShownTypesArrays()
	local tUnitTypes = self:GetAllUnitTypes()

	self.arAllowedTypesSuperPanning =
	{
		self.eObjectTypeMission,
		self.eObjectTypePublicEvent,
		self.eObjectTypeChallenge,
		self.eObjectTypeLocation,
		self.eObjectTypeHexGroup,
		self.eObjectTypeQuest,
		self.eObjectTypeMapTrackedUnit,
		self.eObjectTypeCityDirectionPing,
		self.eObjectTypeNemesisRegion
	}

	self.arAllowedTypesPanning =
	{
		self.eObjectTypeMission,
		self.eObjectTypePublicEvent,
		self.eObjectTypeChallenge,
		self.eObjectTypeLocation,
		self.eObjectTypeHexGroup,
		self.eObjectTypeQuest,
		self.eObjectTypeMapTrackedUnit,
		self.eObjectTypeCityDirectionPing,
		self.eObjectTypeNemesisRegion
	}

	self.arAllowedTypesScaled =
	{
		self.eObjectTypeMission,
		self.eObjectTypePublicEvent,
		self.eObjectTypeChallenge,
		self.eObjectTypeLocation,
		self.eObjectTypeHexGroup,
		self.eObjectTypeQuest,
		self.eObjectTypeMapTrackedUnit,
		self.eObjectTypeCityDirectionPing,
		self.eObjectTypeNemesisRegion
	}

	for i, type in pairs(tUnitTypes) do
		table.insert(self.arAllowedTypesSuperPanning, type)
		table.insert(self.arAllowedTypesPanning, type)
		table.insert(self.arAllowedTypesScaled, type)
	end

	self.arAllowedTypesContinent =
	{
		self.eObjectTypePublicEvent,
		self.eObjectTypeInstancePortal
	}

	self.arAllowedTypesWorld = { } -- use an empty table to hide everything

	-- Here are our arrays for what we actually show after considering user toggling
	self.arShownTypesSuperPanning = { }
	for idx, eType in pairs(self.arAllowedTypesSuperPanning) do
		table.insert(self.arShownTypesSuperPanning, eType)
	end

	self.arShownTypesPanning = { }
	for idx, eType in pairs(self.arAllowedTypesPanning) do
		table.insert(self.arShownTypesPanning , eType)
	end

	self.arShownTypesScaled = { }
	for idx, eType in pairs(self.arAllowedTypesScaled) do
		table.insert(self.arShownTypesScaled , eType)
	end

	self.arShownTypesContinent = { }
	for idx, eType in pairs(self.arAllowedTypesContinent) do
		table.insert(self.arShownTypesContinent , eType)
	end

	self.arShownTypesWorld = { }
	for idx, eType in pairs(self.arAllowedTypesWorld) do
		table.insert(self.arShownTypesWorld , eType)
	end
end

function ZoneMap:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.arPreloadUnits = {}

	return o
end

function ZoneMap:Init()
	Apollo.RegisterAddon(self)
end

function ZoneMap:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	local tSavedData =
	{
		bControlPanelShown = self.bControlPanelShown,
		tCheckedOptions = self.tButtonChecks,
		eZoomLevel = self.wndZoneMap and self.wndZoneMap:GetDisplayMode() or self.eDisplayMode,
		nSaveVersion = knSaveVersion,
	}
	return tSavedData
end

function ZoneMap:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	self.bControlPanelShown = tSavedData.bControlPanelShown -- TODO: Not actually a boolean, OnRestore bugged with booleans at the moment
	if tSavedData.tCheckedOptions then
		self.tButtonChecks = tSavedData.tCheckedOptions
		
		self:RehideAllToggledIcons()
	end
	if tSavedData.eZoomLevel then
		self.eDisplayMode = tSavedData.eZoomLevel
	end

	self:CreateUnitsFromPreload()
end

function ZoneMap:OnLoad()
	Apollo.RegisterEventHandler("UnitCreated", 							"OnPreloadUnitCreated", self)

	self.xmlDoc = XmlDoc.CreateFromFile("ZoneMapForms.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
end

function ZoneMap:OnPreloadUnitCreated(unitNew)
	self.arPreloadUnits[unitNew:GetId()] = unitNew
end

function ZoneMap:OnDocumentReady()
	Apollo.RemoveEventHandler("UnitCreated", self)

	if  self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("ToggleZoneMap", 						"ToggleWindow", self)
	Apollo.RegisterEventHandler("ToggleGhostModeMap",					"OnToggleGhostModeMap", self)
	Apollo.RegisterEventHandler("MapPulseTimer", 						"OnMapPulseTimer", self)
	Apollo.RegisterEventHandler("OptionsUpdated_QuestTracker", 			"OnOptionsUpdated", self)

	Apollo.RegisterEventHandler("QuestHighlightChanged", 				"OnQuestStateChanged", self)
	Apollo.RegisterEventHandler("QuestObjectiveUpdated", 				"OnQuestStateChanged", self)
	Apollo.RegisterEventHandler("QuestStateChanged", 					"OnQuestStateChanged", self)
	Apollo.RegisterEventHandler("GenericEvent_QuestTrackerRenumbered", 	"OnQuestStateChanged", self)

	Apollo.RegisterEventHandler("UnitCreated", 							"OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed", 						"OnUnitDestroyed", self)
	Apollo.RegisterEventHandler("UnitActivationTypeChanged", 			"OnUnitChanged", self)
	Apollo.RegisterEventHandler("UnitMiniMapMarkerChanged", 			"OnUnitChanged", self)
	Apollo.RegisterEventHandler("ChallengeFailArea", 					"OnFailChallenge", self)
	Apollo.RegisterEventHandler("ChallengeFailTime", 					"OnFailChallenge", self)
	Apollo.RegisterEventHandler("ChallengeAbandon", 					"OnRemoveChallengeIcon", self)
	Apollo.RegisterEventHandler("ChallengeCompleted", 					"OnRemoveChallengeIcon", self)
	Apollo.RegisterEventHandler("ChallengeActivate", 					"OnAddChallengeIcon", self)
	Apollo.RegisterEventHandler("ChallengeFlashStartLocation", 			"OnFlashChallengeIcon", self)
	Apollo.RegisterTimerHandler("ChallengeFlashIconTimer", 				"OnStopChallengeFlashIcon", self)
	Apollo.RegisterEventHandler("PlayerPathMissionActivate", 			"OnPlayerPathMissionActivate", self)
	Apollo.RegisterEventHandler("PlayerPathMissionUpdate", 				"OnPlayerPathMissionActivate", self)
	Apollo.RegisterEventHandler("PlayerPathMissionDeactivate", 			"OnPlayerPathMissionDeactivate", self)
	Apollo.RegisterEventHandler("PlayerPathMissionComplete", 			"OnPlayerPathMissionDeactivate", self)
	Apollo.RegisterEventHandler("PlayerPathExplorerPowerMapStarted", 	"OnPlayerPathMissionActivate", self)
	Apollo.RegisterEventHandler("PlayerPathExplorerPowerMapFailed", 	"OnPlayerPathMissionActivate", self)
	Apollo.RegisterEventHandler("PublicEventStart", 					"OnPublicEventUpdate", self)
	Apollo.RegisterEventHandler("PublicEventObjectiveUpdate", 			"OnPublicEventObjectiveUpdate", self)
	Apollo.RegisterEventHandler("PublicEventEnd", 						"OnPublicEventEnd", self)
	Apollo.RegisterEventHandler("PublicEventLeave",						"OnPublicEventEnd", self)
	Apollo.RegisterEventHandler("PublicEventCleared", 					"OnPublicEventCleared", self)
	Apollo.RegisterEventHandler("PublicEventLocationAdded", 			"OnPublicEventUpdate", self)
	Apollo.RegisterEventHandler("PublicEventLocationRemoved", 			"OnPublicEventUpdate", self)
	Apollo.RegisterEventHandler("PublicEventObjectiveLocationAdded", 	"OnPublicEventObjectiveUpdate", self)
	Apollo.RegisterEventHandler("PublicEventObjectiveLocationRemoved", 	"OnPublicEventObjectiveUpdate", self)
	Apollo.RegisterEventHandler("PlayerLevelChange", 					"UpdateQuestList", self)
	Apollo.RegisterEventHandler("HazardShowMinimapUnit", 				"OnHazardShowMinimapUnit", self)
	Apollo.RegisterEventHandler("HazardRemoveMinimapUnit", 				"OnHazardRemoveMinimapUnit", self)
	Apollo.RegisterEventHandler("ZoneMapUpdateHexGroup", 				"OnUpdateHexGroup", self)
	Apollo.RegisterEventHandler("ZoneMapPlayerIndicatorUpdated",		"OnPlayerIndicatorUpdated", self)
	Apollo.RegisterEventHandler("SubZoneChanged", 						"OnSubZoneChanged", self)
	Apollo.RegisterEventHandler("ZoneMapWindowModeChange",				"OnMouseScroll", self)
	Apollo.RegisterEventHandler("ZoneMap_OpenMapToQuest",				"OnZoneMap_OpenMapToQuest", self)
	Apollo.RegisterEventHandler("ChangeWorld", 							"OnWorldChanged", self)
	Apollo.RegisterEventHandler("CityDirectionsList", 					"OnCityDirectionsList", self)
	Apollo.RegisterEventHandler("CityDirectionMarked",					"OnCityDirectionMarked", self)
	Apollo.RegisterEventHandler("CityDirectionsClose",					"OnCityDirectionsClosed", self)

	--Levelup unlocks
	Apollo.RegisterEventHandler("UI_LevelChanged",											"OnLevelChanged", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapAdventure_Astrovoid", 				"OnLevelUpUnlock_WorldMapAdventure_Astrovoid", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapAdventure_Galeras", 					"OnLevelUpUnlock_WorldMapAdventure_Galeras", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapAdventure_Hycrest", 					"OnLevelUpUnlock_WorldMapAdventure_Hycrest", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapAdventure_Malgrave", 				"OnLevelUpUnlock_WorldMapAdventure_Malgrave", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapAdventure_NorthernWilds", 			"OnLevelUpUnlock_WorldMapAdventure_NorthernWilds", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapAdventure_Whitevale", 				"OnLevelUpUnlock_WorldMapAdventure_Whitevale", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapDungeon_UltimateProtogames", 		"OnLevelUpUnlock_WorldMapDungeon_UltimateProtogames", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapDungeon_SwordMaiden", 				"OnLevelUpUnlock_WorldMapDungeon_SwordMaiden", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapDungeon_Skullcano", 					"OnLevelUpUnlock_WorldMapDungeon_Skullcano", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapDungeon_KelVoreth", 					"OnLevelUpUnlock_WorldMapDungeon_KelVoreth", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapDungeon_Stormtalon", 				"OnLevelUpUnlock_WorldMapDungeon_Stormtalon", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapDungeon_ProtogamesAcademyExile",		"OnLevelUpUnlock_WorldMapDungeon_ProtogamesAcademyExile", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapDungeon_ProtogamesAcademyDominion",	"OnLevelUpUnlock_WorldMapDungeon_ProtogamesAcademyDominion", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Wilderrun", 					"OnLevelUpUnlock_WorldMapNewZone_Wilderrun", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Whitevale", 					"OnLevelUpUnlock_WorldMapNewZone_Whitevale", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_NorthernWilds", 				"OnLevelUpUnlock_WorldMapNewZone_NorthernWilds", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Malgrave", 					"OnLevelUpUnlock_WorldMapNewZone_Malgrave", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_LevianBay", 					"OnLevelUpUnlock_WorldMapNewZone_LevianBay", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Grimvault", 					"OnLevelUpUnlock_WorldMapNewZone_Grimvault", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Galeras", 					"OnLevelUpUnlock_WorldMapNewZone_Galeras", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Farside", 					"OnLevelUpUnlock_WorldMapNewZone_Farside", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_EverstarGrove", 				"OnLevelUpUnlock_WorldMapNewZone_EverstarGrove", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Ellevar", 					"OnLevelUpUnlock_WorldMapNewZone_Ellevar", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Deradune", 					"OnLevelUpUnlock_WorldMapNewZone_Deradune", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_CrimsonIsle", 				"OnLevelUpUnlock_WorldMapNewZone_CrimsonIsle", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Celestion", 					"OnLevelUpUnlock_WorldMapNewZone_Celestion", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Auroria", 					"OnLevelUpUnlock_WorldMapNewZone_Auroria", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapNewZone_Algoroc", 					"OnLevelUpUnlock_WorldMapNewZone_Algoroc", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapCapital_Illium", 					"OnLevelUpUnlock_WorldMapCapital_Illium", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_WorldMapCapital_Thayd", 						"OnLevelUpUnlock_WorldMapCapital_Thayd", self)

	--Group Events
	Apollo.RegisterEventHandler("Group_UpdatePosition", 				"OnGroupUpdatePosition", self)			-- ( arMembers )
	Apollo.RegisterEventHandler("Group_Updated", 						"DrawGroupMembers", self)				-- ()
	Apollo.RegisterEventHandler("Group_Join", 							"OnGroupJoin", self)					-- ()
	Apollo.RegisterEventHandler("Group_Add", 							"OnGroupAdd", self)						-- ( name )
	Apollo.RegisterEventHandler("Group_Remove", 						"OnGroupRemove", self)					-- ( name, result )
	Apollo.RegisterEventHandler("Group_Left", 							"OnGroupLeft", self)					-- ( reason )

	Apollo.RegisterEventHandler("ShowLocOnWorldMap", 					"OnShowLoc", self)

	Apollo.RegisterEventHandler("MapTrackedUnitUpdate", 				"OnMapTrackedUnitUpdate", self)
	Apollo.RegisterEventHandler("MapTrackedUnitDisable", 				"OnMapTrackedUnitDisable", self)

	-- City Directions
	Apollo.RegisterTimerHandler("ZoneMap_TimeOutCityDirectionMarker",	"OnZoneMap_TimeOutCityDirectionMarker", self)
	Apollo.CreateTimer("ZoneMap_TimeOutCityDirectionMarker", 300, false)
	Apollo.StopTimer("ZoneMap_TimeOutCityDirectionMarker")

	Apollo.RegisterTimerHandler("ZoneMap_PollCityDirectionsMarker",		"OnZoneMap_PollCityDirectionsMarker", self)
	Apollo.CreateTimer("ZoneMap_PollCityDirectionsMarker", 3, true)
	Apollo.StopTimer("ZoneMap_PollCityDirectionsMarker")

	-- Map Coordinate Delay
	Apollo.RegisterTimerHandler("ZoneMap_MapCoordinateDelay",			"OnZoneMap_MapCoordinateDelay", self)
	Apollo.CreateTimer("ZoneMap_MapCoordinateDelay", 0.25, false)
	Apollo.StopTimer("ZoneMap_MapCoordinateDelay")

	self.wndMain 				= Apollo.LoadForm(self.xmlDoc, "ZoneMapFrame", nil, self)
	self.wndWorldView 			= self.wndMain:FindChild("WorldMapView")
	self.wndZoneMap 			= self.wndMain:FindChild("ZoneMap")

	self:CreateOverlayObjectTypes()

	self.tCityDirectionsLoc		= nil
	self.wndCityDirections		= nil
	self.bMapCoordinateDelay 	= false

	self.tTooltipCompareTable 	= {} -- used for clearing hexes on mouseover

	self.tContButtons =
	{
		self.wndWorldView:FindChild("ContEasternBtn"),
		self.wndWorldView:FindChild("ContWesternBtn"),
		self.wndWorldView:FindChild("ContHalonRingBtn"),
		self.wndWorldView:FindChild("ContCentralBtn"),
		self.wndWorldView:FindChild("ContFarsideBtn")
	}

	self.wndZoneMap:SetGhostWindow(false)
	self.wndZoneMap:SetMinDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.SuperPanning)
	self.wndWorldView:FindChild("ContEasternBtn"):SetData(6)
	self.wndWorldView:FindChild("ContWesternBtn"):SetData(8)
	self.wndWorldView:FindChild("ContHalonRingBtn"):SetData(9)
	self.wndWorldView:FindChild("ContCentralBtn"):SetData(33)
	self.wndWorldView:FindChild("ContFarsideBtn"):SetData(28)

	self.wndMain:Show(false, true)
	self.wndMain:SetSizingMinimum(400, 300)
	--self.wndMain:FindChild("PanningIcon"):Show(false)
	self.wndMain:FindChild("SubzoneToggle"):AttachWindow(self.wndMain:FindChild("SubzoneList"))

	-----------------------------------------------------------------------------------------
	-- Visual Setup
	-----------------------------------------------------------------------------------------

	for iEdge = 1, 6 do -- sets the hexedge sprite
		self.wndZoneMap:SetActiveHexEdgeSprite(iEdge, "sprMap_HexEdge" .. iEdge) -- TODO: These are reversed
		self.wndZoneMap:SetInactiveHexEdgeSprite(iEdge, "sprMap_HexEdge" .. iEdge .. "Lit")
	end
	self.wndZoneMap:SetPlayerArrowSprite("sprMap_PlayerArrow")
	self.wndZoneMap:SetActiveHexSprite("sprMap_HexFill_Base") -- TODO: These are reversed
	self.wndZoneMap:SetInactiveHexSprite("")
	self.wndZoneMap:ShowLabels(true) -- turn on labels
	self.wndZoneMap:SetLabelTextColor(CColor.new(165/255, 255/255, 255/255, 1.0))
	-----------------------------------------------------------------------------------------

	self.wndGhostOptionPanel = self.wndMain:FindChild("GhostModeOptionPanel")
	self.wndGhostOptionPanel:FindChild("GhostSlider"):SetValue(Apollo.GetConsoleVariable("ui.zoneMap.ghostedBackgroundAlpha") or 0)
	self.wndGhostOptionPanel:Show(false)
	self.wndMain:FindChild("GhostModeOptionBtn"):AttachWindow(self.wndGhostOptionPanel)

	Apollo.SetConsoleVariable("ui.zoneMap.ghostedIconsAlpha", 0.7)
	Apollo.SetConsoleVariable("ui.zoneMap.POIDotColor", knPOIColorHidden)

	self.wndMapControlPanel = Apollo.LoadForm(self.xmlDoc, "ZoneMapControlPanel", self.wndMain:FindChild("ZoneMapControlPanelParent"), self)
	self.wndMapControlPanel:FindChild("QuestPaneToggle"):SetCheck(true)
	self.wndMapControlPanel:FindChild("MissionPaneToggle"):SetCheck(true)
	self.wndMapControlPanel:FindChild("ChallengePaneToggle"):SetCheck(true)
	self.wndMapControlPanel:FindChild("PublicEventPaneToggle"):SetCheck(true)
	self.wndMapControlPanel:FindChild("QuestPaneToggle"):AttachWindow(self.wndMapControlPanel:FindChild("QuestPaneContent"))
	self.wndMapControlPanel:FindChild("MissionPaneToggle"):AttachWindow(self.wndMapControlPanel:FindChild("MissionPaneContent"))
	self.wndMapControlPanel:FindChild("ChallengePaneToggle"):AttachWindow(self.wndMapControlPanel:FindChild("ChallengePaneContent"))
	self.wndMapControlPanel:FindChild("PublicEventPaneToggle"):AttachWindow(self.wndMapControlPanel:FindChild("PublicEventPaneContent"))

	self.wndMapControlPanel:FindChild("ControlPanelInnerFrame"):ArrangeChildrenVert(0)

	self.wndMain:FindChild("ZoneComplexToggle"):AttachWindow(self.wndMain:FindChild("ZoneComplexList"))

	self.wndMain:FindChild("MarkersToggle"):AttachWindow(self.wndMain:FindChild("MarkersList"))

	self.bIgnoreQuestStateChanged = false
	self.eLastZoomLevel = nil
	self.bControlPanelShown = false -- lives across sessions

	-----------------------------------------------------------------------------------------

	-- build table of bools that correspond to icon types for the player to toggle
	self.tToggledIcons =
	{
		bTracked 			= true,
		bPublicEvents 		= true,
		bMissions 			= true,
		bChallenges 		= true,
		bGroupObjectives 	= true
	}

	self:CreatePOIIcons()

	self.tGroupMembers 				= {}

	self.tHexGroupObjects 			= {}
	self.tChallengeObjects 			= {}
	self.tUnitsShown 				= {}	-- For Quests, Vendors, Instance Portals, and Bind Points which all use UnitCreated/UnitDestroyed events
	self.tUnitsHidden 				= {}	-- Units that we're tracking but are out of the current subzone
	self.arPulses 					= {}
	self.strZoneName 				= ""
	self.idCurrentZone 				= 0
	self.idChallengeFlashingIcon	= nil
	self.bQuestTrackerByDistance 	= g_InterfaceOptions and g_InterfaceOptions.Carbine.bQuestTrackerByDistance or false


	if not self.tButtonChecks then
		self.tButtonChecks			= {}
	end
	Apollo.CreateTimer("MapPulseTimer", 0.013, true)
	Apollo.StopTimer("MapPulseTimer")

	self:OnPublicEventsCheck()
	local tCurrentZoneMap = GameLib.GetCurrentZoneMap()
	if tCurrentZoneMap then
		self.wndZoneMap:SetZone(tCurrentZoneMap.id)
		self:OnMissionsCheck()
	end
	self:UpdateQuestList()
	self:OnResizeOptionsPane() -- sets initial size in case the XML is off

	if g_wndTheZoneMap == nil then
		-- Thanks to PacketDancer for reminding me to add this.
		g_wndTheZoneMap = self.wndZoneMap
	end

	self:BuildShownTypesArrays()

	-- Top two options
	self.wndMain:FindChild("MarkerPaneButtonList"):FindChild("OptionsBtnLabels"):SetCheck(true)
	self.wndMain:FindChild("MarkerPaneButtonList"):FindChild("OptionsBtnLabels"):FindChild("Label"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
	if Apollo.GetConsoleVariable("draw.hexGrid") then
		self.wndMain:FindChild("MarkerPaneButtonList"):FindChild("OptionsBtnTerrainHex"):SetCheck(true)
		self.wndMain:FindChild("MarkerPaneButtonList"):FindChild("OptionsBtnTerrainHex"):FindChild("Label"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
	else
		self.wndMain:FindChild("MarkerPaneButtonList"):FindChild("OptionsBtnTerrainHex"):SetCheck(false)
		self.wndMain:FindChild("MarkerPaneButtonList"):FindChild("OptionsBtnTerrainHex"):FindChild("Label"):SetTextColor(ApolloColor.new("UI_TextMetalGoldHighlight"))
	end

	-- Rest of options
	local tButtonList =
	{
		[ktMarkerCategories.QuestNPCs] 			= {strLabel = Apollo.GetString("ZoneMap_QuestNPCs"), 			bShown = true,	strIcon = "Icon_MapNode_Map_Quest"},
		[ktMarkerCategories.TrackedQuests] 		= {strLabel = Apollo.GetString("ZoneMap_TrackedQuests"), 		bShown = true,	strIcon = "sprMM_QuestTracked"},
		[ktMarkerCategories.Missions] 			= {strLabel = Apollo.GetString("ZoneMap_Missions"), 			bShown = true,	strIcon = ""}, -- Will be updated later
		[ktMarkerCategories.Challenges] 		= {strLabel = Apollo.GetString("ZoneMap_Challenges"), 			bShown = true,	strIcon = "sprChallengeTypeGenericLarge"},
		[ktMarkerCategories.PublicEvents] 		= {strLabel = Apollo.GetString("ZoneMap_PublicEvents"), 		bShown = true,	strIcon = "sprMM_POI"},
		[ktMarkerCategories.Tradeskills] 		= {strLabel = Apollo.GetString("ZoneMap_Tradeskills"), 			bShown = true,	strIcon = "Icon_MapNode_Map_Tradeskill"},
		[ktMarkerCategories.Vendors] 			= {strLabel = Apollo.GetString("ZoneMap_NearbyVendors"), 		bShown = true,	strIcon = "Icon_MapNode_Map_Vendor"},
		[ktMarkerCategories.Services] 			= {strLabel = Apollo.GetString("ZoneMap_Services"), 			bShown = true,	strIcon = "Icon_MapNode_Map_Vendor"},
		[ktMarkerCategories.Portals] 			= {strLabel = Apollo.GetString("ZoneMap_NearbyPortals"), 		bShown = true,	strIcon = "Icon_MapNode_Map_Portal"},
		[ktMarkerCategories.BindPoints] 		= {strLabel = Apollo.GetString("ZoneMap_NearbyBindPoints"), 	bShown = true,	strIcon = "Icon_MapNode_Map_Gate"},
		[ktMarkerCategories.GroupObjectives] 	= {strLabel = Apollo.GetString("ZoneMap_GroupObjectives"), 		bShown = true,	strIcon = "GroupLeaderIcon"},
		[ktMarkerCategories.MiningNodes] 		= {strLabel = Apollo.GetString("ZoneMap_MiningNodes"), 			bShown = true,	strIcon = "Icon_MapNode_Map_Node_Mining"},
		[ktMarkerCategories.RelicNodes] 		= {strLabel = Apollo.GetString("ZoneMap_RelicHunterNodes"), 	bShown = true,	strIcon = "Icon_MapNode_Map_Node_Relic"},
		[ktMarkerCategories.SurvivalistNodes] 	= {strLabel = Apollo.GetString("ZoneMap_SurvivalistNodes"), 	bShown = true,	strIcon = "Icon_MapNode_Map_Node_Tree"},
		[ktMarkerCategories.FarmingNodes] 		= {strLabel = Apollo.GetString("ZoneMap_FarmingNodes"), 		bShown = true,	strIcon = "Icon_MapNode_Map_Node_Plant"},
		[ktMarkerCategories.NemesisRegions] 	= {strLabel = Apollo.GetString("ZoneMap_NemesisRegions"), 		bShown = false, strIcon = "Icon_MapNode_Map_Rival"},
		[ktMarkerCategories.Taxis] 				= {strLabel = Apollo.GetString("ZoneMap_Taxis"), 				bShown = true,	strIcon = "Icon_MapNode_Map_Taxi"},
		[ktMarkerCategories.CityDirections] 	= {strLabel = Apollo.GetString("ZoneMap_CityDirections"), 		bShown = true,	strIcon = "Icon_MapNode_Map_CityDirections"},
	}

	for eCategory, tBtnData in ipairs(tButtonList) do
		local wndCurr = self:FactoryProduce(self.wndMain:FindChild("MarkerPaneButtonList"), "MarkerBtn", eCategory)
		if not self.tButtonChecks or self.tButtonChecks[eCategory] == nil then
			self.tButtonChecks[eCategory] =  tBtnData.bShown
		end
		wndCurr:SetCheck(self.tButtonChecks[eCategory])
		wndCurr:FindChild("MarkerBtnLabel"):SetText(tBtnData.strLabel)
		wndCurr:FindChild("MarkerBtnImage"):SetSprite(tBtnData.strIcon)
		wndCurr:FindChild("MarkerBtnLabel"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
	end
	self.wndMain:FindChild("MarkerPaneButtonList"):ArrangeChildrenVert(0)

	self.wndMapControlPanel:Show(false)

	self:BuildCustomMarkerInfo()

	self:OnLevelChanged(GameLib.GetPlayerLevel())

	self.objActiveRegionUserData = nil
	self.arHoverRegionUserDataList = {}

	self.tUnitCreateQueue = {}
	self.timerCreateDelay = ApolloTimer.Create(0.25, true, "OnUnitCreateDelayTimer", self)
	self.timerCreateDelay:Start()

	self:CreateUnitsFromPreload()

	for idx = 2, GroupLib.GetMemberCount() do
		local tInfo = GroupLib.GetGroupMember(idx)
		if tInfo.bIsOnline then
			self.tGroupMembers[idx] =
			{
				nIndex = idx,
				strName = tInfo.strCharacterName,
			}

			local unitMember = GroupLib.GetUnitForGroupMember(idx)
			if unitMember ~= nil and unitMember:IsValid() then
				self.tUnitCreateQueue[#self.tUnitCreateQueue + 1] = unitMember
			end
		end
	end
	
	self:RehideAllToggledIcons()
end

function ZoneMap:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Map"), {"ToggleZoneMap", "WorldMap", "Icon_Windows32_UI_CRB_InterfaceMenu_Map"})
end

function ZoneMap:OnOptionsUpdated()
	if g_InterfaceOptions and g_InterfaceOptions.Carbine.bQuestTrackerByDistance ~= nil then
		self.bQuestTrackerByDistance = g_InterfaceOptions.Carbine.bQuestTrackerByDistance
	else
		self.bQuestTrackerByDistance = true
	end

	self:OnQuestStateChanged()
end

function ZoneMap:CreateUnitsFromPreload()
	if self.bAddonRestoredOrLoaded then
		self.unitPlayer = GameLib.GetPlayerUnit()

		-- Process units created while form was loading
		for idUnit, unitNew in pairs(self.arPreloadUnits) do
			if unitNew ~= nil and unitNew:IsValid() then
				self:OnUnitCreated(unitNew)
			end
		end
		self.arPreloadUnits = nil
	end
	self.bAddonRestoredOrLoaded = true
end

function ZoneMap:ToggleWindow()
	if self.wndMain:IsVisible() then
		Event_FireGenericEvent("GenericEvent_CloseZoneCompletion")
		self.wndMain:Show(false)
		self.eDisplayMode = self.wndZoneMap:GetDisplayMode()
		Apollo.StopTimer("MapPulseTimer")
	else
		Event_FireGenericEvent("GenericEvent_OpenZoneCompletion", self.wndMain:FindChild("ZoneMapCompletionParent"))
		self.wndZoneMap:SetGhostWindow(false)
		self.wndMain:Invoke()
		self.wndMain:ToFront()
		self.wndMain:FindChild("ZoneComplexList"):Show(false)
		self.wndMain:FindChild("MarkersList"):Show(false)
		self:UpdateCurrentZone()
		self:UpdateQuestList()
		self:UpdateMissionList()
		self:UpdateChallengeList()
		self:UpdatePublicEventList()
		self:ReloadNemesisRegions()

		if self.bControlPanelShown then
			self:OnToggleControlsOn()
		else
			self:OnToggleControlsOff()
		end

		local tZoneInfo = GameLib.GetCurrentZoneMap(self.idCurrentZone)
		if tZoneInfo then
			self:HelperBuildZoneDropdown(tZoneInfo.continentId)
			self.wndMain:FindChild("ReturnBtn"):SetData(tZoneInfo)
		end

		self:AddQuestIndicators()
		self.wndMain:FindChild("ZoneComplexToggle"):SetData(self.idCurrentZone)
		self.wndZoneMap:SetZone(self.idCurrentZone)
		self.wndZoneMap:SetDisplayMode(self.eDisplayMode)
		self.wndZoneMap:CenterOnPlayer()
		self.wndZoneMap:SetMinDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.SuperPanning)
		self:SetControls()

		Event_FireGenericEvent("MapGhostMode", false)
		self.wndMain:ToFront()
		
		--tPathSoldier 		= {strSprite = "Icon_MapNode_Map_Soldier",					strType = Apollo.GetString("ZoneMap_SoldierMission")}, -- must always match the sprite passed with the event
		--tPathSettler 		= {strSprite = "Icon_MapNode_Map_Settler",					strType = Apollo.GetString("ZoneMap_SettlerMission")}, -- must always match the sprite passed with the event
		--tPathScientist 		= {strSprite = "Icon_MapNode_Map_Scientist",				strType = Apollo.GetString("ZoneMap_ScientistMission")}, -- must always match the sprite passed with the event
		--tPathExplorer 		= {strSprite = "Icon_MapNode_Map_Explorer",					strType = Apollo.GetString("ZoneMap_ExplorerMission")}, -- must always match the sprite passed with the event

		-- TODO: Refactor
		local ePlayerPathType = PlayerPathLib.GetPlayerPathType()
		local wndMarkerPathIcon = self.wndMain:FindChild("MarkerPaneButtonList"):FindChildByUserData(3):FindChild("MarkerBtnImage")
		if ePlayerPathType == PlayerPathLib.PlayerPathType_Soldier then
			self.tPOITypes[self.eObjectTypeMission] = {strSprite = "Icon_MapNode_Map_Soldier", strType = Apollo.GetString("ZoneMap_SoldierMission")}
			self.wndZoneMap:SetOverlayTypeInfo(self.eObjectTypeMission, ktHexColor.tPath.crBorder, ktHexColor.tPath.crInterior, "sprMM_SmallIconSoldier", "sprMM_SmallIconSoldier")
		elseif ePlayerPathType == PlayerPathLib.PlayerPathType_Settler then
			self.tPOITypes[self.eObjectTypeMission] = {strSprite = "Icon_MapNode_Map_Settler", strType = Apollo.GetString("ZoneMap_SettlerMission")}
			self.wndZoneMap:SetOverlayTypeInfo(self.eObjectTypeMission, ktHexColor.tPath.crBorder, ktHexColor.tPath.crInterior, "sprMM_SmallIconSettler", "sprMM_SmallIconSettler")
		elseif ePlayerPathType == PlayerPathLib.PlayerPathType_Explorer then
			self.tPOITypes[self.eObjectTypeMission] = {strSprite = "Icon_MapNode_Map_Explorer", strType = Apollo.GetString("ZoneMap_ExplorerMission")}
			self.wndZoneMap:SetOverlayTypeInfo(self.eObjectTypeMission, ktHexColor.tPath.crBorder, ktHexColor.tPath.crInterior, "sprMM_SmallIconExplorer", "sprMM_SmallIconExplorer")
		elseif ePlayerPathType == PlayerPathLib.PlayerPathType_Scientist then
			self.tPOITypes[self.eObjectTypeMission] = {strSprite = "Icon_MapNode_Map_Scientist", strType = Apollo.GetString("ZoneMap_ScientistMission")}
			self.wndZoneMap:SetOverlayTypeInfo(self.eObjectTypeMission, ktHexColor.tPath.crBorder, ktHexColor.tPath.crInterior, "sprMM_SmallIconScientist", "sprMM_SmallIconScientist")
		end
		
		wndMarkerPathIcon:SetSprite(self.tPOITypes[self.eObjectTypeMission].strSprite)
		self:OnZoomChange()

		self.wndZoneMap:HighlightRegionsByUserData(self.objActiveRegionUserData)

		-- TODO: This is the temp way to disable indyDots. They should just be removed.
		Apollo.SetConsoleVariable("indyDots.sprite", "")
		Apollo.SetConsoleVariable("indyDots.maxDots", 0)
		Apollo.StartTimer("MapPulseTimer")
	end

	if self.oShownLocObject then
		self.wndZoneMap:RemoveObject(self.oShownLocObject)
		self.oShownLocObject = nil
	end
end

function ZoneMap:OnToggleGhostModeMap() -- for keyboard input turning ghost mode map on/off
	local bShow = not self.wndZoneMap:IsShowingGhostWindow()
	self.wndZoneMap:SetGhostWindow(bShow)
end

function ZoneMap:UpdateCurrentZone()
	local idPrevZone = self.idCurrentZone
	local tZoneInfo = GameLib.GetCurrentZoneMap(idPrevZone)
	if tZoneInfo and tZoneInfo.id ~= idPrevZone then
		self.idCurrentZone = tZoneInfo.id
		self.strZoneName = tZoneInfo.strName
		self.wndZoneMap:SetZone(self.idCurrentZone)
		self:OnZoneChanged()
	end
end

--------------------//-----------------------------

function ZoneMap:OnWindowMove(wndHandler, wndControl)
	if self.wndMain:GetWidth() < 575 or self.wndMain:GetHeight() < 460 then -- Also see HelperCheckAndBuildSubzones for Subzone Auto Hiding
		if not self.bAutoHideSummaryScreen then
			Event_FireGenericEvent("GenericEvent_ZoneMap_SetMapCompletionShown", false)
		end
		self.bAutoHideSummaryScreen = true
	elseif self.bAutoHideSummaryScreen then
		Event_FireGenericEvent("GenericEvent_ZoneMap_SetMapCompletionShown", true)
		self.bAutoHideSummaryScreen = false
	end
end

function ZoneMap:OnZoneMapChange(wndHandler, wndControl, strContinent, idZone) -- Map changed from clicking in continent view
	self.wndMain:FindChild("ZoneComplexToggle"):SetData(idZone) -- No need to set Continent since it has to be the current one
end

function ZoneMap:OnZoneComplexListBtn(wndHandler, wndControl) -- ZoneComplexListBtn
	if not wndHandler:GetData() then
		return
	end

	local tZoneInfo = wndHandler:GetData()
	self.wndZoneMap:SetMinDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.SuperPanning) -- in case we're on a different continent
	self.wndMain:FindChild("ZoneComplexToggle"):SetData(tZoneInfo.id)
	self.wndMain:FindChild("ZoneComplexToggle"):SetText(tZoneInfo.strName)
	self.wndMain:FindChild("ZoneComplexList"):Show(false)
	self.wndZoneMap:SetZone(tZoneInfo.id)
	self.wndZoneMap:SetDisplayMode(3)

	self:HelperBuildZoneDropdown(tZoneInfo.continentId)

	self:SetControls()
end

function ZoneMap:OnContinentNormalBtn(wndHandler, wndControl)
	local idSelected = wndControl:GetData()
	local tHomeZone = GameLib.GetCurrentZoneMap()
	self:HelperBuildZoneDropdown(idSelected)

	if tHomeZone == nil or idSelected ~= tHomeZone.continentId then -- looking at a different continent; set an arbitrary zone and zoom
		local arZones = self.wndZoneMap:GetContinentZoneInfo(idSelected)
		local idFirstZone = 0
		for idx, tZone in pairs(arZones) do
			if tZone.id ~= nil and tZone.id ~= 0 then
				idFirstZone = tZone.id
				break
			end
		end

		self.wndZoneMap:SetZone(idFirstZone)
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Continent)
		self.wndZoneMap:SetMinDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.SuperPanning)
		self.wndMain:FindChild("ZoneComplexToggle"):SetData(idFirstZone)
	else
		self.wndZoneMap:SetZone(tHomeZone.id)
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Continent)
		self.wndZoneMap:SetMinDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.SuperPanning)
		self.wndMain:FindChild("ZoneComplexToggle"):SetData(tHomeZone.id)
	end
	self:SetControls()
	self:OnZoomChange()
end

function ZoneMap:OnContinentCustomBtn(wndHandler, wndControl)
	local tSelected = self.wndZoneMap:GetZoneInfo(wndControl:GetData())
	local tHomeZone = GameLib.GetCurrentZoneMap()

	self.wndZoneMap:SetZone(tSelected.id)
	self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Scaled)
	self.wndZoneMap:SetMinDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.SuperPanning)
	self.wndMain:FindChild("ZoneComplexToggle"):SetData(tSelected.id)
	self.wndMain:FindChild("ZoneComplexToggle"):Enable(false)
	self:SetControls()
	self:OnZoomChange()
end

function ZoneMap:OnShowLoc(tLocInfo) -- Also from City Directions
	if tLocInfo.zoneMap == nil then
		return
	end

	if not self.wndMain:IsVisible() then
		self:ToggleWindow()
	else
		self.wndMain:ToFront()
	end

	self.strZoneName = tLocInfo.zoneMap.strName
	self.idCurrentZone = tLocInfo.zoneMap.id
	self.wndMain:FindChild("ZoneComplexToggle"):SetData(self.idCurrentZone)
	self.wndZoneMap:SetZone(self.idCurrentZone)

	local tInfo =
	{
		strIcon 	= "sprMM_QuestZonePulse",
		crObject 	= CColor.new(1, 1, 1, 1),
		strIconEdge = "",
		crEdge 		= CColor.new(1, 1, 1, 1),
		fRadius 	= 1.0,
	}

	if self.oShownLocObject then
		self.wndZoneMap:RemoveObject(self.oShownLocObject)
		self.oShownLocObject = nil
	end

	self.oShownLocObject = self.wndZoneMap:AddObject(self.eObjectTypeLocation, tLocInfo.worldLoc, "", tInfo, {bNeverShowOnEdge = true})

	self:SetControls()
	Apollo.RegisterTimerHandler("WorldLocTimer", "OnWorldLocTimer", self) -- make a timer so the questLog click doesn't stomp the ToFront
	Apollo.CreateTimer("WorldLocTimer", 100, false)
end

function ZoneMap:OnWorldLocTimer()
	self.wndMain:ToFront()
end

--------------------//-----------------------------
--------------------//-----------------------------

function ZoneMap:OnCloseBtn()
	self.wndMain:Show(false)
	self.wndMapControlPanel:Show(false)
	self.wndMain:FindChild("ZoneComplexList"):Show(false)
	self.eDisplayMode = self.wndZoneMap:GetDisplayMode()
	Apollo.StopTimer("MapPulseTimer")
	Event_FireGenericEvent("GenericEvent_CloseZoneCompletion")
end

function ZoneMap:OnWindowClosed()
	if self.oShownLocObject ~= nil then
		self.wndZoneMap:RemoveObject(self.oShownLocObject)
		self.oShownLocObject = nil
	end
	if self.wndZoneMap ~= nil and self.wndZoneMap:IsValid() then
		self.eDisplayMode = self.wndZoneMap:GetDisplayMode()
	end
	Apollo.StopTimer("MapPulseTimer")
end

function ZoneMap:OnWorldChanged()
	local tCurrentZoneInfo = GameLib.GetCurrentZoneMap()
	if tCurrentZoneInfo ~= nil then
		self.strZoneName = tCurrentZoneInfo.strName
		self.idCurrentZone = tCurrentZoneInfo.id
	end
	Apollo.StopTimer("MapPulseTimer")
	self:SetControls()
end

---------------------------------------------------
----------------Control Set Functions--------------
function ZoneMap:ToggleGhostModeOn()
	self.wndZoneMap:SetGhostWindow(true)
	Event_FireGenericEvent("MapGhostMode", true)
	self:ToggleWindow()
end

function ZoneMap:OnGhostSlider(wndHandler, wndControl)
	local nGhostValue = wndHandler:GetValue()
	Apollo.SetConsoleVariable("ui.zoneMap.ghostedBackgroundAlpha", nGhostValue)
	Apollo.SetConsoleVariable("ui.zoneMap.ghostedArtOverlayAlpha", nGhostValue)
end

function ZoneMap:OnGhostModeOptionOK()
	self.wndGhostOptionPanel:Show(false)
end

function ZoneMap:OnGhostModeOptionTest()
	self.wndZoneMap:SetGhostWindow(true)
	Event_FireGenericEvent("MapGhostMode", true)
	self:ToggleWindow()
end

function ZoneMap:OnToggleControlsOn(wndHandler, wndControl)
	self.bControlPanelShown = true
	self.wndMain:FindChild("ZoneMapControlPanelParent"):Show(true)
	self.wndMapControlPanel:Show(true, false)
	self.wndMain:FindChild("ToggleControlsBtn"):SetCheck(true)
	self.wndMain:FindChild("GrabberFrame"):Show(false)

	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("ToggleControlsBtn"):GetAnchorOffsets()
	self.wndMain:FindChild("ToggleControlsBtn"):SetAnchorOffsets(-418, nTop, -365, nBottom)
	self.wndMain:FindChild("ToggleControlsBtn"):SetTooltip(Apollo.GetString("CRB_Collapse_zone_selection_controls"))
end

function ZoneMap:OnToggleControlsOff(wndHandler, wndControl)
	self.bControlPanelShown = false
	self.wndMain:FindChild("ZoneMapControlPanelParent"):Show(false)
	self.wndMapControlPanel:Show(false, false)
	self.wndMain:FindChild("ZoneComplexList"):Show(false)
	self.wndMain:FindChild("ToggleControlsBtn"):SetCheck(false)
	self.wndMain:FindChild("GrabberFrame"):Show(true)

	local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("ToggleControlsBtn"):GetAnchorOffsets()
	self.wndMain:FindChild("ToggleControlsBtn"):SetAnchorOffsets(-52, nTop, 1, nBottom)
	self.wndMain:FindChild("ToggleControlsBtn"):SetTooltip(Apollo.GetString("CRB_Expand_zone_selection_controls"))

end

function ZoneMap:OnResizeOptionsPane()
	local wndParent = self.wndMapControlPanel
	local nLeft, nTop, nRight, nBottom = wndParent:FindChild("QuestPaneContainer"):GetAnchorOffsets()
	wndParent:FindChild("QuestPaneContainer"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + (wndParent:FindChild("QuestPaneToggle"):IsChecked() and 206 or 52))

	nLeft, nTop, nRight, nBottom = wndParent:FindChild("MissionPaneContainer"):GetAnchorOffsets()
	wndParent:FindChild("MissionPaneContainer"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + (wndParent:FindChild("MissionPaneToggle"):IsChecked() and 206 or 52))

	nLeft, nTop, nRight, nBottom = wndParent:FindChild("ChallengePaneContainer"):GetAnchorOffsets()
	wndParent:FindChild("ChallengePaneContainer"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + (wndParent:FindChild("ChallengePaneToggle"):IsChecked() and 160 or 52))

	nLeft, nTop, nRight, nBottom = wndParent:FindChild("PublicEventPaneContainer"):GetAnchorOffsets()
	wndParent:FindChild("PublicEventPaneContainer"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + (wndParent:FindChild("PublicEventPaneToggle"):IsChecked() and 160 or 52))

	nLeft, nTop, nRight, nBottom = wndParent:GetAnchorOffsets()
	nBottom = nTop + wndParent:FindChild("QuestPaneContainer"):GetHeight() + wndParent:FindChild("MissionPaneContainer"):GetHeight() + wndParent:FindChild("ChallengePaneContainer"):GetHeight() + wndParent:FindChild("PublicEventPaneContainer"):GetHeight()
	wndParent:SetAnchorOffsets(nLeft, nTop, nRight, nBottom + 35)
	wndParent:FindChild("ControlPanelInnerFrame"):ArrangeChildrenVert(0)
end

-- TODO: a lot of this doesn't need to happen so frequently and can be broken out
function ZoneMap:SetControls() -- runs off timer, sets the controls to reflect the map's display
	if not self.wndMain:IsVisible() then -- don't update when no map is shown
		return
	end

	local tCurrentInfo = self.wndZoneMap:GetZoneInfo()
	if not tCurrentInfo then
		return
	end

	local bZoneChanged = false
	if self.idCurrentZone ~= tCurrentInfo.id then
		bZoneChanged = true
		self.idCurrentZone = tCurrentInfo.id
		self:OnZoneChanged()
	end

	if tCurrentInfo == nil then
		self.wndMain:FindChild("ZoneComplexToggle"):Enable(false)
		self.wndWorldView:Show(true)
		self.wndZoneMap:Show(false)
		return
	end

	local eZoomLevel = self.wndZoneMap:GetDisplayMode()
	local tZoneMapEnums = ZoneMapWindow.CodeEnumDisplayMode

	local bValidZoneZoomLevels =
	{
		[ZoneMapWindow.CodeEnumDisplayMode.SuperPanning] = true,
		[ZoneMapWindow.CodeEnumDisplayMode.Panning] = true,
		[ZoneMapWindow.CodeEnumDisplayMode.Scaled] = true,
	}

	-- Reset if different
	if self.eLastZoomLevel ~= eZoomLevel or bZoneChanged then
		-- TODO: Put more stuff here
		self.wndMain:FindChild("SubzoneListContent"):DestroyChildren()
	end

	-- No GPS Signal
	local signalLost = false
	if eZoomLevel ~= tZoneMapEnums.World and eZoomLevel ~= tZoneMapEnums.Continent then
		signalLost = not self.wndZoneMap:IsShowPlayerOn()
	end

	if tCurrentInfo.parentZoneId ~= 0 then
		signalLost = false
	end

	self.wndMain:FindChild("PlayerCursorHidden"):Show(signalLost)

	local tCurrentContinent = self.wndZoneMap:GetContinentInfo(tCurrentInfo.continentId)
	local tHomeZone = self.wndMain:FindChild("ReturnBtn"):GetData()
	local tHomeContinent = tHomeZone and self.wndZoneMap:GetContinentInfo(tHomeZone.continentId) or nil

	self.wndZoneMap:Show(true)
	self.wndWorldView:Show(eZoomLevel == tZoneMapEnums.World)

	local bPanning = (eZoomLevel == tZoneMapEnums.Panning or eZoomLevel == tZoneMapEnums.SuperPanning)
	--self.wndMain:FindChild("PanningIcon"):Show(bPanning) -- GOTCHA: Show instead of enable
	self.wndMain:FindChild("ZoomOutBtn"):Enable(eZoomLevel ~= tZoneMapEnums.World)
	self.wndMain:FindChild("ZoomInBtn"):Enable(eZoomLevel ~= tZoneMapEnums.SuperPanning and (eZoomLevel ~= tZoneMapEnums.Scaled or self.wndZoneMap:CanZoomZone()))
	self.wndMain:FindChild("GhostBtn"):Enable(bPanning or eZoomLevel == tZoneMapEnums.Scaled)
	self.wndMain:FindChild("ReturnBtn"):Enable(eZoomLevel ~= tZoneMapEnums.Scaled or not tHomeZone or tHomeZone.id ~= tCurrentInfo.id)

	if eZoomLevel == tZoneMapEnums.Continent and (not tCurrentContinent or not tCurrentContinent.bCanDisplay) then -- Continent not visible
		self.wndZoneMap:SetDisplayMode(self.eLastZoomLevel == tZoneMapEnums.Scaled and tZoneMapEnums.World or tZoneMapEnums.Scaled)
		self:SetControls()
		return
	end

	if self.eLastZoomLevel ~= eZoomLevel then
		if eZoomLevel == tZoneMapEnums.SuperPanning then -- SuperPanning
		elseif eZoomLevel == tZoneMapEnums.Panning then -- Panning
			if not self.wndZoneMap:CanZoomZone() then -- kick to scaled if the map now fits
				self.wndZoneMap:SetDisplayMode(tZoneMapEnums.Scaled)
				self.wndZoneMap:SetMinDisplayMode(tZoneMapEnums.Scaled)
			else
				self.wndZoneMap:SetMinDisplayMode(tZoneMapEnums.SuperPanning)
			end
		elseif eZoomLevel == tZoneMapEnums.Scaled then -- Scaled
			self.wndZoneMap:SetMinDisplayMode(self.wndZoneMap:CanZoomZone() and tZoneMapEnums.SuperPanning or tZoneMapEnums.Scaled)
		elseif eZoomLevel == tZoneMapEnums.Continent then -- Continent
			if not tHomeContinent or tCurrentContinent.id ~= tHomeContinent.id then
				--self.wndZoneMap:SetMinDisplayMode(tZoneMapEnums.Continent)
			else
				self.wndMain:FindChild("ZoneComplexToggle"):SetData(tHomeZone.id)
				self.wndZoneMap:SetZone(tHomeZone.id)
				self.wndZoneMap:SetMinDisplayMode(tZoneMapEnums.SuperPanning)
			end
		end

		-- Needs to be last
		self.eLastZoomLevel = eZoomLevel
		Event_FireGenericEvent("GenericEvent_ZoneMap_ZoomLevelChanged", bValidZoneZoomLevels[eZoomLevel])
	end

	if eZoomLevel == tZoneMapEnums.World and tHomeContinent then
		for idx = 1, #self.tContButtons do
			self.tContButtons[idx]:FindChild("CurrentRunner"):Show(tHomeContinent and self.tContButtons[idx]:GetData() == tHomeContinent.id)
		end
		self.wndZoneMap:SetZone(tHomeZone.id)
		self.wndMain:FindChild("ZoneComplexToggle"):SetData(tHomeZone.id)
	end
	-- Subzone Toggle
	self:HelperCheckAndBuildSubzones(tCurrentInfo, eZoomLevel)

	-- Dropdown name
	local strZoneMapText = Apollo.GetString("CRBZoneMap_SelectAZone")
	if eZoomLevel == tZoneMapEnums.SuperPanning or eZoomLevel == tZoneMapEnums.Panning or eZoomLevel == tZoneMapEnums.Scaled then
		strZoneMapText = tCurrentInfo.strName
		-- TODO: strZoneMapText = (tHomeZone and tHomeZone.id ~= tCurrentInfo.id) and tCurrentInfo.strName or tCurrentInfo.strName .. " (Current)"
	elseif eZoomLevel == tZoneMapEnums.World then
		strZoneMapText = Apollo.GetString("ZoneCompletion_WorldCompletion")
	elseif eZoomLevel == tZoneMapEnums.Continent and tHomeContinent and tCurrentContinent.id == tHomeContinent.id then
		strZoneMapText = tCurrentContinent.strName
	end
	self.wndMain:FindChild("ZoneComplexToggle"):SetText(strZoneMapText)

	-- Enable / Disable Zone Toggle:
	local tInfoForEnable = self.wndZoneMap:GetZoneInfo(self.wndMain:FindChild("ZoneComplexToggle"):GetData())
	if tInfoForEnable then
		self.wndMain:FindChild("ZoneComplexToggle"):Enable(eZoomLevel ~= tZoneMapEnums.World and self.wndZoneMap:GetContinentInfo(tInfoForEnable.continentId).bCanDisplay)
	end
end

function ZoneMap:OnZoneChanged()
	Event_FireGenericEvent("GenericEvent_ZoneMap_ZoneChanged", self.idCurrentZone)
	self:ReloadNemesisRegions()
end

function ZoneMap:HelperCheckAndBuildSubzones(tZoneInfo, eZoomLevel) -- This repeatedly calls on a timer
	if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Continent or eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.World then
		self.wndMain:FindChild("SubzoneToggle"):Show(false)
		return
	end

	local tSubZoneInfo = self.wndZoneMap:GetAllSubZoneInfo(tZoneInfo.parentZoneId ~= 0 and tZoneInfo.parentZoneId or tZoneInfo.id)
	local nHeightOfEntry = 0
	
	for idx, tZoneEntry in pairs(tSubZoneInfo or {}) do
		local wndCurr = self:FactoryProduce(self.wndMain:FindChild("SubzoneListContent"), "ZoneComplexListEntry", tZoneEntry.id)
		wndCurr:FindChild("ZoneComplexListBtn"):SetData(tZoneEntry)
		wndCurr:FindChild("ZoneComplexListBtn"):SetCheck(tZoneInfo.id == tZoneEntry.id)
		wndCurr:FindChild("ZoneComplextListTitle"):SetText(tZoneEntry.strName)
		nHeightOfEntry = wndCurr:GetHeight() 
	end

	self.wndMain:FindChild("SubzoneListContent"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("SubzoneToggle"):Show(tSubZoneInfo and #tSubZoneInfo > 0)
	if tSubZoneInfo and #tSubZoneInfo > 0 then
		local nSubZoneTotalCount = #tSubZoneInfo 
		local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("SubzoneList"):GetAnchorOffsets()
		self.wndMain:FindChild("SubzoneList"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + (nSubZoneTotalCount * nHeightOfEntry) + 9) -- + 9 of top bottom padding
	end

end

function ZoneMap:HelperBuildZoneDropdown(idContinent) -- This only calls on button events, like picking from a dropdown menu
	self.wndMain:FindChild("ZoneSelectItems"):DestroyChildren()
	
	local tZoneInfo = self.wndZoneMap:GetContinentZoneInfo(idContinent)
	--local tZoneInfo = self.wndZoneMap:GetContinentZoneInfo(tZoneInfo.parentZoneId ~= 0 and tZoneInfo.parentZoneId or tZoneInfo.id)
	local nHeightOfEntry = 0
	local nZoneTotalCount = 0
	for key, tZoneEntry in pairs(tZoneInfo) do
		if tZoneEntry.parentZoneId == 0 then -- zones only, no subzones
			local wndCurr = self:FactoryProduce(self.wndMain:FindChild("ZoneSelectItems"), "ZoneComplexListEntry", tZoneEntry.id)
			wndCurr:FindChild("ZoneComplexListBtn"):SetData(tZoneEntry)
			wndCurr:FindChild("ZoneComplextListTitle"):SetText(tZoneEntry.strName)
			nHeightOfEntry = wndCurr:GetHeight()
			nZoneTotalCount = nZoneTotalCount + 1
		end
	end
	self.wndMain:FindChild("ZoneSelectItems"):ArrangeChildrenVert(0)
	
	if nZoneTotalCount > 0 then
		local nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("ZoneComplexList"):GetAnchorOffsets()
		self.wndMain:FindChild("ZoneComplexList"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + (nZoneTotalCount * nHeightOfEntry) + 9) -- + 9 of top bottom padding
	end
end


function ZoneMap:OnZoomChange()
	local eZoomLevel = self.wndZoneMap:GetDisplayMode()
	if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.SuperPanning then -- Super Panning
		self.wndZoneMap:SetObjectsVisibility(self.arShownTypesSuperPanning)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Panning then -- Panning
		self.wndZoneMap:SetObjectsVisibility(self.arShownTypesPanning)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Scaled then -- Scaled
		self.wndZoneMap:SetObjectsVisibility(self.arShownTypesScaled)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Continent then -- Continent
		self.wndZoneMap:SetObjectsVisibility(self.arShownTypesContinent)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.World then -- world
		self.wndZoneMap:SetObjectsVisibility(self.arShownTypesWorld)
	end
	local tMouse = self.wndZoneMap:GetMouse()
	self:OnZoneMapMouseMove(self.wndZoneMap, self.wndZoneMap, tMouse.x, tMouse.y)
end

function ZoneMap:OnMouseScroll(eDisplayMode)
	self:SetControls()
	self:OnZoomChange()
end

function ZoneMap:OnZoomIn()
	local eZoomLevel = self.wndZoneMap:GetDisplayMode() -- 1: Panning, 2: Scaled, 3: Continent
	if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.SuperPanning then -- Super Panning
		return -- error handling (shouldn't be able to zoom at this level)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Panning then -- Panning
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.SuperPanning)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Scaled then -- Scaled
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Panning)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Continent then -- Continent
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Scaled)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.World then -- world
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Continent)
	end
	self:SetControls()
	self:OnZoomChange()
end

function ZoneMap:OnZoomOut()
	local eZoomLevel = self.wndZoneMap:GetDisplayMode() -- 1: Panning, 2: Scaled, 3: Continent
	if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.SuperPanning then -- Super Panning
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Panning)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Panning then -- Panning
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Scaled)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Scaled then -- Scaled
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Continent)
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Continent then -- Continent
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.World)
	end
	self:SetControls()
	self:OnZoomChange()
end

function ZoneMap:OnReturnBtn(wndHandler, wndControl)
	local tHomeZone = wndControl:GetData()
	if tHomeZone ~= nil then
		self.wndMain:FindChild("ZoneComplexToggle"):SetData(tHomeZone.id)
		self.wndZoneMap:SetZone(tHomeZone.id)
		self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Scaled)
		self:HelperBuildZoneDropdown(tHomeZone.continentId)
	end
	self:SetControls()
end

function ZoneMap:OnQuestStateChanged()
	if self.bIgnoreQuestStateChanged then
		return
	end

	self:AddQuestIndicators()
	self:UpdateQuestList()
end

function ZoneMap:AddQuestIndicators()
	if self.wndZoneMap == nil then
		return
	end

	self.tEpisodes = QuestLib.GetTrackedEpisodes(self.bQuestTrackerByDistance)

	-- Clear epiCurr list
	self.wndZoneMap:RemoveRegionByType(self.eObjectTypeQuest)

	-- Iterate over all the episodes adding non-active first
	local nQuest = 1
	for idx, epiCurr in ipairs(self.tEpisodes) do
		-- Add entries for each queCurr in the epiCurr
		for idx2, queCurr in ipairs(epiCurr:GetTrackedQuests(0, self.bQuestTrackerByDistance)) do
			if queCurr:IsActiveQuest() then
				local tQuestRegions = queCurr:GetMapRegions()
				for nObjIdx, tObjRegions in pairs(tQuestRegions) do
					self.wndZoneMap:AddRegion(self.eObjectTypeQuest, tObjRegions.nWorldZoneId, tObjRegions.tRegions, queCurr, tObjRegions.tIndicator, tostring(nQuest), self.tPOITypes[self.eObjectTypeQuestNew].strSprite)
				end

				nQuest = nQuest + 1
			elseif self.tToggledIcons.bTracked then
				local tQuestRegions = queCurr:GetMapRegions()
				for nObjIdx, tObjRegions in pairs(tQuestRegions) do
					self.wndZoneMap:AddRegion(self.eObjectTypeQuest, tObjRegions.nWorldZoneId, tObjRegions.tRegions, queCurr, tObjRegions.tIndicator, tostring(nQuest), self.tPOITypes[self.eObjectTypeQuestNew].strSprite)
				end

				nQuest = nQuest + 1
			end
		end
	end
end

--------------------//-----------------------------

function ZoneMap:GetMissionTooltip(pmCurrent)
	if not pmCurrent or self.tTooltipCache[pmCurrent] then
		return ""
	end
	self.tTooltipCache[pmCurrent] = true

	local tPathNames =
	{
		[PlayerPathLib.PlayerPathType_Soldier] 		= Apollo.GetString("ZoneMap_SoldierMission"),
		[PlayerPathLib.PlayerPathType_Settler] 		= Apollo.GetString("ZoneMap_SettlerMission"),
		[PlayerPathLib.PlayerPathType_Scientist] 	= Apollo.GetString("ZoneMap_ScientistMission"),
		[PlayerPathLib.PlayerPathType_Explorer]		= Apollo.GetString("ZoneMap_ExplorerMission")
	}

	local strType = string.format("<P><T Font=\"%s\" TextColor=\"%s\">%s</T></P>", "CRB_InterfaceMedium", "UI_TextHoloTitle", String_GetWeaselString(Apollo.GetString("CRB_ZoneMapColon"), tPathNames[PlayerPathLib.GetPlayerPathType()]))
	local strName = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceMedium", "ffffffff", pmCurrent:GetName())
	return String_GetWeaselString(Apollo.GetString("ZoneMap_MissionTypeName"), strType, strName)
end

function ZoneMap:GetPublicEventTooltip(peEvent)
	if not peEvent or self.tTooltipCache[peEvent] then
		return ""
	end
	self.tTooltipCache[peEvent] = true

	local strType = string.format("<P><T Font=\"%s\" TextColor=\"%s\">%s</T></P>", "CRB_InterfaceMedium", "UI_TextHoloTitle", Apollo.GetString("ZoneMap_PublicEventTooltipLabel"))
	local strName = ""
	if PublicEvent.is(peEvent) then
		strName = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceMedium", "ffffffff", peEvent:GetName())
	elseif PublicEventObjective.is(peEvent) then
		strName = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceMedium", "ffffffff", peEvent:GetDescription())
	end

	if strName == "" then
		return strName
	else
		return String_GetWeaselString(Apollo.GetString("ZoneMap_MissionTypeName"), strType, strName)
	end
end

function ZoneMap:GetChallengeTooltip(oChallenge)
	if not oChallenge or self.tTooltipCache[oChallenge] then
		return ""
	end
	self.tTooltipCache[oChallenge] = true

	local strType = string.format("<P><T Font=\"%s\" TextColor=\"%s\">%s</T></P>", "CRB_InterfaceMedium", "UI_TextHoloTitle", Apollo.GetString("ZoneMap_ChallengeTooltipLabel"))
	local strName = ""
	if Challenges.is(oChallenge) then
		strName =  string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceMedium", "ffffffff",  oChallenge:GetName())
	end

	if strName == "" then
		return strName
	else
		return String_GetWeaselString(Apollo.GetString("ZoneMap_MissionTypeName"), strType, strName)
	end
end

function ZoneMap:GetHexGroupTooltip(oHexGroup)
	if not oHexGroup or self.tTooltipCache[oHexGroup] then
		return ""
	end
	self.tTooltipCache[oHexGroup] = true

	local strType = string.format("<P><T Font=\"%s\" TextColor=\"%s\">%s</T></P>", "CRB_InterfaceMedium", "UI_TextHoloTitle", Apollo.GetString("ZoneMap_HexTooltipLabel"))
	local strName = ""
	if HexGroups.is(oHexGroup) then
		strName = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceMedium", "ffffffff", oHexGroup:GetTooltip())
	end

	if strName == "" then
		return strName
	else
		return String_GetWeaselString(Apollo.GetString("ZoneMap_MissionTypeName"), strType, strName)
	end
end

function ZoneMap:GetNemesisRegionTooltip(oNemesisRegion)
	if not oNemesisRegion or self.tTooltipCache[oNemesisRegion] then
		return ""
	end
	self.tTooltipCache[oNemesisRegion] = true

	local tRegion = self.wndZoneMap:GetNemesisRegionInfo(oNemesisRegion)
	if tRegion ~= nil then
		local strType = string.format("<P><T Font=\"%s\" TextColor=\"%s\">%s</T></P>", "CRB_InterfaceMedium", "UI_TextHoloTitle", String_GetWeaselString(Apollo.GetString("ZoneMap_NemesisTooltipLabel"), tRegion.strFactionName))
		local strName = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceMedium", "ffffffff", tRegion.strDescription)
		return String_GetWeaselString(Apollo.GetString("ZoneMap_MissionTypeName"), strType, strName)
	end
	return ""
end

function ZoneMap:OnGenerateTooltip(wndHandler, wndControl, eType, nX, nY)
	local eZoomLevel = self.wndZoneMap:GetDisplayMode()
	if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.World or eZoomLevel == Continent or eZoomLevel == SolarSystem then
		return
	end

	local strTooltipString = ""
	--local strType = ""
	local strName = ""
	local bTooltip = false

	self.tTooltipCache = {}
	for hoverIdx, hoverData in pairs(self.arHoverRegionUserDataList) do
		if hoverData ~= self.objActiveRegionUserData and PublicEventObjective.is(hoverData) == false then
			self.wndZoneMap:UnhighlightRegionsByUserData(hoverData)
		end
	end

	self.arHoverRegionUserDataList = {}
	local tTooltips = {}
	local tTypesUsed = {}

	if eType == Tooltip.TooltipGenerateType_Default then
		local nCount = 0
		local bAdded = false
		local tPoint = self.wndZoneMap:WindowPointToClientPoint(nX, nY)
		local tMap = self.wndZoneMap:GetRegionsAt(tPoint.x, tPoint.y)

		if tMap == nil then
			return
		end
		
		for key, tHexes in pairs(tMap) do -- hex groups
			local strName = ""

			if self.tButtonChecks[tHexes.eType] then
				local bShowRegion = true
				local strType = self.tPOITypes[tHexes.eType].strType
				
				

				if tHexes.eType == self.eObjectTypeMission then
					self.tTooltipCache[tHexes.userData] = true
					strName = tHexes.userData:GetName()
				elseif tHexes.eType == self.eObjectTypePublicEvent then
					self.tTooltipCache[tHexes.userData] = true
					
					if PublicEvent.is(tHexes.userData) then
						strName = tHexes.userData:GetName()
					elseif PublicEventObjective.is(tHexes.userData) then
						strName = tHexes.userData:GetDescription()
					end
				elseif tHexes.eType == self.eObjectTypeChallenge then
					self.tTooltipCache[tHexes.userData] = true
					strName = tHexes.userData:GetName()
					bShowRegion = false
				elseif tHexes.eType == self.eObjectTypeHexGroup then
					self.tTooltipCache[tHexes.userData] = true
					strName = tHexes.userData:GetTooltip()
					bShowRegion = false
				elseif tHexes.eType == self.eObjectTypeNemesisRegion then
					self.tTooltipCache[tHexes.userData] = true
					self.tTooltipCompareTable[tHexes.userData] = tHexes.eType
					bShowRegion = false
					
					local tRegion = self.wndZoneMap:GetNemesisRegionInfo(tHexes.userData)
					if tRegion ~= nil then
						strFaction = string.format("<P><T Font=\"%s\" TextColor=\"%s\">%s</T></P>", "CRB_InterfaceMedium", "UI_TextHoloTitle", String_GetWeaselString(Apollo.GetString("ZoneMap_NemesisTooltipLabel"), tRegion.strFactionName))
						strName = strFaction .. tRegion.strDescription
					end
				elseif tHexes.eType == self.eObjectTypeQuest and not self.tTooltipCache[tHexes.userData] then
					self.tTooltipCache[tHexes.userData] = true
					local strLevel = string.format("<T Font=\"%s\" TextColor=\"%s\">(%s)</T>", "CRB_InterfaceMedium", ktConColors[tHexes.userData:GetColoredDifficulty()], tHexes.userData:GetConLevel())
					strName = string.format("<T Font=\"%s\" TextColor=\"%s\">%s %s</T>", "CRB_InterfaceMedium", "ffffffff", tHexes.userData:GetTitle(), strLevel)
				end
				
				if not tTooltips[tHexes.eType] then
					tTooltips[tHexes.eType] = 
					{
						strCategory = strType,
						tStrings = {}
					}
					
					table.insert(tTypesUsed, tHexes.eType)
				end
				
				local strName = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceMedium", "ffffffff", strName)
				
				if not tTooltips[tHexes.eType].tStrings[strName] then
					tTooltips[tHexes.eType].tStrings[strName] = {}
				end
				
				if tHexes.unit then
					table.insert(tTooltips[tHexes.eType].tStrings[strName], tHexes.unit:GetId())
				end
				
				self.tTooltipCompareTable[tHexes.userData] = tHexes.eType

				if bShowRegion then
					self.wndZoneMap:HighlightRegionsByUserData(tHexes.userData)
					table.insert(self.arHoverRegionUserDataList, tHexes.userData)
				end
			end
		end

		local tMapObjects = self.wndZoneMap:GetObjectsAt(tPoint.x, tPoint.y) -- all others
		for key, tHexes in pairs(tMapObjects) do
			if self.tButtonChecks[self.tPOITypes[tHexes.eType].eCategory] then
				local strName = ""
				local strType = self.tPOITypes[tHexes.eType] and self.tPOITypes[tHexes.eType].strType or eType					
				
				if tHexes.eType == self.eObjectTypeMission or tHexes.eType == self.eObjectTypePublicEvent or tHexes.eType == self.eObjectTypeChallenge then
					self.tTooltipCache[tHexes.userData] = true
					strName = tHexes.userData:GetName()
				elseif tHexes.eType == self.eObjectTypePublicEvent then
					self.tTooltipCache[tHexes.userData] = true
					
					if PublicEvent.is(tHexes.userData) then
						strName = tHexes.userData:GetName()
					elseif PublicEventObjective.is(tHexes.userData) then
						strName = tHexes.userData:GetDescription()
					end
				elseif tHexes.eType == self.eObjectTypeHexGroup then
					self.tTooltipCache[tHexes.userData] = true
					strName = tHexes.userData:GetTooltip()
				elseif tHexes.eType == self.eObjectTypeNemesisRegion then
					self.tTooltipCache[tHexes.userData] = true

					local tRegion = self.wndZoneMap:GetNemesisRegionInfo(tHexes.userData)
					if tRegion ~= nil then
						strFaction = string.format("<P><T Font=\"%s\" TextColor=\"%s\">%s</T></P>", "CRB_InterfaceMedium", "UI_TextHoloTitle", String_GetWeaselString(Apollo.GetString("ZoneMap_NemesisTooltipLabel"), tRegion.strFactionName))
						strName = strFaction .. tRegion.strDescription
					end
				elseif tHexes.eType == self.eObjectTypeLocation then
					return
				else
					strName = tHexes.strName
				end
				
				if not tTooltips[tHexes.eType] then
					tTooltips[tHexes.eType] = 
					{
						strCategory = strType,
						tStrings = {}
					}
					
					table.insert(tTypesUsed, tHexes.eType)
				end
				
				local strName = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceMedium", "ffffffff", strName)
				if not tTooltips[tHexes.eType].tStrings[strName] then
					tTooltips[tHexes.eType].tStrings[strName] = {}
				end
				
				if tHexes.unit then
					table.insert(tTooltips[tHexes.eType].tStrings[strName], tHexes.unit:GetId())
				end
			end
		end
	end
	
	
	table.sort(tTypesUsed)
	
	
	for idx, eCategory in pairs(tTypesUsed) do
		local tCategoryTooltips = tTooltips[eCategory]
		
		strTooltipString = strTooltipString .. string.format("<P><T Font=\"%s\" TextColor=\"%s\">%s</T></P>", "CRB_InterfaceMedium", "UI_TextHoloTitle", tCategoryTooltips.strCategory)
		
		for strName, tIds in pairs(tCategoryTooltips.tStrings) do
			local nCount = 0
			local strCount = ""
			for idUnit, bExists in pairs(tIds) do
				nCount = nCount + 1
			end
			
			if nCount > 1 then
				strCount = String_GetWeaselString(Apollo.GetString("Vendor_ItemCount"), nCount)
			end
			
			strTooltipString = strTooltipString .. string.format("<P>-   " .. strName .. " " .. strCount .. "</P>")				
		end
	end

	-- unlight hexes that are no longer highlighted
	for idx, vStored in pairs(self.tTooltipCompareTable) do
		if self.tTooltipCache[idx] == nil then
			if self.tTooltipCompareTable[idx] == self.eObjectTypeMission then
				self.tTooltipCompareTable[idx] = nil
			elseif self.tTooltipCompareTable[idx] == self.eObjectTypePublicEvent then
				self.tTooltipCompareTable[idx] = nil
			elseif self.tTooltipCompareTable[idx] == self.eObjectTypeChallenge then
				self.tTooltipCompareTable[idx] = nil
			elseif self.tTooltipCompareTable[idx] == self.eObjectTypeHexGroup then
				self.tTooltipCompareTable[idx] = nil
			elseif self.tTooltipCompareTable[idx] == self.eObjectTypeNemesisRegion then
				self.tTooltipCompareTable[idx] = nil
			elseif self.tTooltipCompareTable[idx] == self.eObjectTypeQuest then
				self.tTooltipCompareTable[idx] = nil
			end
		end
	end

	wndControl:SetTooltipType(Window.TPT_OnCursor)
	wndControl:SetTooltip(strTooltipString)
end

function ZoneMap:OnHazardShowMinimapUnit(idHazard, unitHazard, bIsBeneficial)
	if unitHazard == nil then
		return
	end

	local tInfo =
	{
		strIconEdge 	= "",
		crObject 		= CColor.new(1, 1, 1, 1),
		crEdge 			= CColor.new(1, 1, 1, 1),
		bAboveOverlay 	= false,
		strIcon 		= (bIsBeneficial and "sprMM_ZoneBenefit" or "sprMM_ZoneHazard")
	}
	self.wndZoneMap:AddUnit(unitHazard, self.eObjectTypeHazard, tInfo, {bNeverShowOnEdge = true, bFixedSizeMedium = true})
end

function ZoneMap:OnHazardRemoveMinimapUnit(idHazard, unitHazard)
	if unitHazard == nil then
		return
	end

	self.wndZoneMap:RemoveUnit(unitHazard)
end

function ZoneMap:OnUpdateHexGroup(hexGroup)
	if hexGroup == nil then return end

	self:UpdateCurrentZone()
	local nIdHexGroup = hexGroup:GetId()

	if hexGroup:IsVisible() then
		local eTypeHexGroup = self.eObjectTypeHexGroup

		if self.tHexGroupObjects[nIdHexGroup] then
			self.wndZoneMap:RemoveRegionByUserData(eTypeHexGroup, hexGroup)
		end
		self.tHexGroupObjects[nIdHexGroup] = hexGroup
		self.wndZoneMap:AddRegion(eTypeHexGroup, 0, hexGroup:GetHexes(self.idCurrentZone), hexGroup)
		self.wndZoneMap:HighlightRegionsByUserData(hexGroup)
	else
		local hexRemoved = self.tHexGroupObjects[nIdHexGroup]
		self.tHexGroupObjects[nIdHexGroup] = nil
		self.wndZoneMap:RemoveRegionByUserData(eTypeHexGroup, hexRemoved)
	end
end

function ZoneMap:OnPlayerIndicatorUpdated()
	self:SetControls()
end

function ZoneMap:OnSubZoneChanged()
  	if self.tUnitsShown then
		for idx, tCurr in pairs(self.tUnitsShown) do
			self.wndZoneMap:RemoveUnit(tCurr.unitValue)
			self.tUnitsShown[tCurr.unitValue:GetId()] = nil
			self:OnUnitCreated(tCurr.unitValue)
		end
	end

	-- check for any units that are now back in the subzone
  	if self.tUnitsHidden then
		for idx, tCurr in pairs(self.tUnitsHidden) do
			self.tUnitsHidden[tCurr.unitValue:GetId()] = nil
			self:OnUnitCreated(tCurr.unitValue)
		end
	end

	local tCurrentZoneMap = GameLib.GetCurrentZoneMap(self.idCurrentZone)
	if tCurrentZoneMap and tCurrentZoneMap.id ~= self.idCurrentZone then
		self.idCurrentZone = tCurrentZoneMap.id
		self.wndZoneMap:SetZone(self.idCurrentZone)
		self:OnMissionsCheck()
		self:OnZoneChanged()
	end

	self:SetControls()
end

-----------------------------------------------------------------------------------------------
-- Marker Buttons
-----------------------------------------------------------------------------------------------

function ZoneMap:OnToggleLabels(wndHandler, wndControl)
	self.wndZoneMap:ShowLabels(wndHandler:IsChecked())

	if wndHandler:IsChecked() then
		wndHandler:FindChild("Label"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
		Apollo.SetConsoleVariable("ui.zoneMap.POIDotColor", knPOIColorHidden)
	else
		wndHandler:FindChild("Label"):SetTextColor(ApolloColor.new("UI_TextMetalGoldHighlight"))
		Apollo.SetConsoleVariable("ui.zoneMap.POIDotColor", knPOIColorShown)
	end
end

function ZoneMap:OnTerrainHexCheck(wndHandler, wndControl)
	wndHandler:FindChild("Label"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
	Apollo.SetConsoleVariable("draw.hexGrid", true)
end

function ZoneMap:OnTerrainHexUncheck(wndHandler, wndControl)
	wndHandler:FindChild("Label"):SetTextColor(ApolloColor.new("UI_TextMetalGoldHighlight"))
	Apollo.SetConsoleVariable("draw.hexGrid", false)
end

function ZoneMap:SetTypeVisibility(eToggledType, bVisible)
	local eZoomLevel = self.wndZoneMap:GetDisplayMode()
	if bVisible then
		for idx, eType in pairs(self.arAllowedTypesSuperPanning) do
			if eToggledType == eType then
				table.insert(self.arShownTypesSuperPanning, eType)
				if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.SuperPanning then
					self.wndZoneMap:ShowObjectsByType(eToggledType)
					self.wndZoneMap:ShowRegionsByType(eToggledType)
				end
			end
		end

		for idx, eType in pairs(self.arAllowedTypesPanning) do
			if eToggledType == eType then
				table.insert(self.arShownTypesPanning, eType)
				if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Panning then
					self.wndZoneMap:ShowObjectsByType(eToggledType)
					self.wndZoneMap:ShowRegionsByType(eToggledType)
				end
			end
		end

		for idx, eType in pairs(self.arAllowedTypesScaled) do
			if eToggledType == eType then
				table.insert(self.arShownTypesScaled, eType)
				if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Scaled then
					self.wndZoneMap:ShowObjectsByType(eToggledType)
					self.wndZoneMap:ShowRegionsByType(eToggledType)
				end
			end
		end

		for idx, eType in pairs(self.arAllowedTypesContinent) do
			if eToggledType == eType then
				table.insert(self.arShownTypesContinent, eType)
				if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Continent then
					self.wndZoneMap:ShowObjectsByType(eToggledType)
					self.wndZoneMap:ShowRegionsByType(eToggledType)
				end
			end
		end

		for idx, eType in pairs(self.arAllowedTypesWorld) do
			if eToggledType == eType then
				table.insert(self.arShownTypesWorld, eType)
				if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.World then
					self.wndZoneMap:ShowObjectsByType(eToggledType)
					self.wndZoneMap:ShowRegionsByType(eToggledType)
				end
			end
		end
	else
		for idx, eType in pairs(self.arShownTypesSuperPanning) do
			if eToggledType == eType then
				table.remove(self.arShownTypesSuperPanning, idx)
				if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.SuperPanning then
					self.wndZoneMap:HideObjectsByType(eToggledType)
					self.wndZoneMap:HideRegionsByType(eToggledType)
				end
			end
		end

		for idx, eType in pairs(self.arShownTypesPanning) do
			if eToggledType == eType then
				table.remove(self.arShownTypesPanning, idx)
				if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Panning then
					self.wndZoneMap:HideObjectsByType(eToggledType)
					self.wndZoneMap:HideRegionsByType(eToggledType)
				end
			end
		end

		for idx, eType in pairs(self.arShownTypesScaled) do
			if eToggledType == eType then
				table.remove(self.arShownTypesScaled, idx)
				if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Scaled then
					self.wndZoneMap:HideObjectsByType(eToggledType)
					self.wndZoneMap:HideRegionsByType(eToggledType)
				end
			end
		end

		for idx, eType in pairs(self.arShownTypesContinent) do
			if eToggledType == eType then
				table.remove(self.arShownTypesContinent, idx)
				if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Continent then
					self.wndZoneMap:HideObjectsByType(eToggledType)
					self.wndZoneMap:HideRegionsByType(eToggledType)
				end
			end
		end

		for idx, eType in pairs(self.arShownTypesWorld) do
			if eToggledType == eType then
				table.remove(self.arShownTypesWorld, idx)
				if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.World then
					self.wndZoneMap:HideObjectsByType(eToggledType)
					self.wndZoneMap:HideRegionsByType(eToggledType)
				end
			end
		end
	end
end

function ZoneMap:OnMarkerBtnCheck(wndHandler, wndControl)
	local eType = wndHandler:GetData()
	if eType == ktMarkerCategories.QuestNPCs then
		self:SetTypeVisibility(self.eObjectTypeQuestReward, true)
		self:SetTypeVisibility(self.eObjectTypeQuestReceiving, true)
		self:SetTypeVisibility(self.eObjectTypeQuestNew, true)
		self:SetTypeVisibility(self.eObjectTypeQuestNewTradeskill, true)
		self:SetTypeVisibility(self.eObjectTypeQuestSoon, true)
		self:SetTypeVisibility(self.eObjectTypeQuestTarget, true)
	elseif eType == ktMarkerCategories.TrackedQuests then
		self.tToggledIcons.bTracked = true
		self:AddQuestIndicators()
		self:UpdateQuestList()
	elseif eType == ktMarkerCategories.Missions then
		self:OnMissionsCheck()
	elseif eType == ktMarkerCategories.Challenges then
		self:OnChallengesCheck()
	elseif eType == ktMarkerCategories.PublicEvents then
		self:OnPublicEventsCheck()
	elseif eType == ktMarkerCategories.Tradeskills then
		self:SetTypeVisibility(self.eObjectTypeTradeskills, true)
	elseif eType == ktMarkerCategories.Vendors then
		self:SetTypeVisibility(self.eObjectTypeVendor, true)
	elseif eType == ktMarkerCategories.Services then
		self:SetTypeVisibility(self.eObjectTypeAuctioneer, true)
		self:SetTypeVisibility(self.eObjectTypeCommodity, true)
		self:SetTypeVisibility(self.eObjectTypeCostume, true)
		self:SetTypeVisibility(self.eObjectTypeBank, true)
		self:SetTypeVisibility(self.eObjectTypeGuildBank, true)
		self:SetTypeVisibility(self.eObjectTypeGuildRegistrar, true)
		self:SetTypeVisibility(self.eObjectTypeCREDDExchange, true)
		self:SetTypeVisibility(self.eObjectTypeMail, true)
		self:SetTypeVisibility(self.eObjectTypeConvert, true)
	elseif eType == ktMarkerCategories.Portals then
		self.tToggledIcons.bInstances = true
		self:SetTypeVisibility(self.eObjectTypeInstancePortal, true)
	elseif eType == ktMarkerCategories.BindPoints then
		self.tToggledIcons.bBindPoints = true
		self:SetTypeVisibility(self.eObjectTypeBindPointActive, true)
		self:SetTypeVisibility(self.eObjectTypeBindPointInactive, true)
	elseif eType == ktMarkerCategories.GroupObjectives then
		self.tToggledIcons.bGroupObjectives = true
	elseif eType == ktMarkerCategories.MiningNodes then
		self:SetTypeVisibility(self.eObjectTypeMiningNode, true)
	elseif eType == ktMarkerCategories.RelicNodes then
		self:SetTypeVisibility(self.eObjectTypeRelicHunterNode, true)
	elseif eType == ktMarkerCategories.SurvivalistNodes then
		self:SetTypeVisibility(self.eObjectTypeSurvivalistNode, true)
	elseif eType == ktMarkerCategories.FarmingNodes then
		self:SetTypeVisibility(self.eObjectTypeFarmingNode, true)
	elseif eType == ktMarkerCategories.NemesisRegions then
		self:SetTypeVisibility(self.eObjectTypeNemesisRegion, true)
	elseif eType == ktMarkerCategories.Taxis then
		self:SetTypeVisibility(self.eObjectTypeVendorFlightPathNew, true)
		self:SetTypeVisibility(self.eObjectTypeVendorFlight, true)
	elseif eType == ktMarkerCategories.CityDirections then
		self:SetTypeVisibility(self.eObjectCityDirections, true)
	end

	self.tButtonChecks[eType] = true
	wndHandler:FindChild("MarkerBtnLabel"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
end

function ZoneMap:OnMarkerBtnUncheck(wndHandler, wndControl)
	local eType = wndHandler:GetData()
	if eType == ktMarkerCategories.QuestNPCs then
		self:SetTypeVisibility(self.eObjectTypeQuestReward, false)
		self:SetTypeVisibility(self.eObjectTypeQuestReceiving, false)
		self:SetTypeVisibility(self.eObjectTypeQuestNew, false)
		self:SetTypeVisibility(self.eObjectTypeQuestNewTradeskill, false)
		self:SetTypeVisibility(self.eObjectTypeQuestNewSoon, false)
		self:SetTypeVisibility(self.eObjectTypeQuestTarget, false)
	elseif eType == ktMarkerCategories.TrackedQuests then
		self.tToggledIcons.bTracked = false
		self:AddQuestIndicators()
		self:UpdateQuestList()
	elseif eType == ktMarkerCategories.Missions then
		self:OnMissionsUncheck()
	elseif eType == ktMarkerCategories.Challenges then
		self:OnChallengesUncheck()
	elseif eType == ktMarkerCategories.PublicEvents then
		self:OnPublicEventsUncheck()
	elseif eType == ktMarkerCategories.Tradeskills then
		self:SetTypeVisibility(self.eObjectTypeTradeskills, false)
	elseif eType == ktMarkerCategories.Vendors then
		self:SetTypeVisibility(self.eObjectTypeVendor, false)
	elseif eType == ktMarkerCategories.Services then
		self:SetTypeVisibility(self.eObjectTypeCommodity, false)
		self:SetTypeVisibility(self.eObjectTypeAuctioneer, false)
		self:SetTypeVisibility(self.eObjectTypeCostume, false)
		self:SetTypeVisibility(self.eObjectTypeBank, false)
		self:SetTypeVisibility(self.eObjectTypeGuildBank, false)
		self:SetTypeVisibility(self.eObjectTypeGuildRegistrar, false)
		self:SetTypeVisibility(self.eObjectTypeCREDDExchange, false)
		self:SetTypeVisibility(self.eObjectTypeMail, false)
		self:SetTypeVisibility(self.eObjectTypeConvert, false)
	elseif eType == ktMarkerCategories.Portals then
		self:SetTypeVisibility(self.eObjectTypeInstancePortal, false)
	elseif eType == ktMarkerCategories.BindPoints then
		self:SetTypeVisibility(self.eObjectTypeBindPointActive, false)
		self:SetTypeVisibility(self.eObjectTypeBindPointInactive, false)
	elseif eType == ktMarkerCategories.GroupObjectives then
		self.tToggledIcons.bGroupObjectives = false
	elseif eType == ktMarkerCategories.MiningNodes then
		self:SetTypeVisibility(self.eObjectTypeMiningNode, false)
	elseif eType == ktMarkerCategories.RelicNodes then
		self:SetTypeVisibility(self.eObjectTypeRelicHunterNode, false)
	elseif eType == ktMarkerCategories.SurvivalistNodes then
		self:SetTypeVisibility(self.eObjectTypeSurvivalistNode, false)
	elseif eType == ktMarkerCategories.FarmingNodes then
		self:SetTypeVisibility(self.eObjectTypeFarmingNode, false)
	elseif eType == ktMarkerCategories.NemesisRegions then
		self:SetTypeVisibility(self.eObjectTypeNemesisRegion, false)
	elseif eType == ktMarkerCategories.Taxis then
		self:SetTypeVisibility(self.eObjectTypeVendorFlightPathNew, false)
		self:SetTypeVisibility(self.eObjectTypeVendorFlight, false)
	elseif eType == ktMarkerCategories.CityDirections then
		self:SetTypeVisibility(self.eObjectCityDirections, false)
	end

	self.tButtonChecks[eType] = false
	wndHandler:FindChild("MarkerBtnLabel"):SetTextColor(ApolloColor.new("UI_BtnTextGoldListNormal"))
end

function ZoneMap:OnMissionsCheck(wndHandler, wndControl)
	if wndControl ~= nil then  -- nil if coming from map change
		self.tToggledIcons.bMissions = true
	end

	local epiCurrent = PlayerPathLib.GetCurrentEpisode()
	if epiCurrent then
		for key, pmCurrent in ipairs(epiCurrent:GetMissions()) do
			self:OnPlayerPathMissionActivate(pmCurrent)
		end
	end
end

function ZoneMap:OnChallengesCheck(wndHandler, wndControl)
	if wndControl ~= nil then  -- nil if coming from map change
		self.tToggledIcons.bChallenges = true
	end

	local tChallenges = ChallengesLib.GetActiveChallengeList()
	if tChallenges then
		for key, chalCurrent in pairs(tChallenges) do
			self:OnAddChallengeIcon(chalCurrent)
		end
	end
end

function ZoneMap:OnPublicEventsCheck(wndHandler, wndControl)
	if wndControl ~= nil then  -- nil if coming from map change
		self.tToggledIcons.bPublicEvents = true
	end

	local tEvents = PublicEventsLib.GetActivePublicEventList()
	if tEvents then
		for key, peEvent in pairs(tEvents) do
			self:OnPublicEventUpdate(peEvent)
		end
	end
end

function ZoneMap:ReloadNemesisRegions()
	self.wndZoneMap:RemoveRegionByType(self.eObjectTypeNemesisRegion)

	local tRegions = self.wndZoneMap:GetAllNemesisRegionInfo()
	if tRegions ~= nil then
		for idx, tRegion in pairs(tRegions) do
			local tHexes = self.wndZoneMap:GetHexGroupHexes(self.idCurrentZone, tRegion.hexGroupId);
			self.wndZoneMap:AddRegion(self.eObjectTypeNemesisRegion, 0, tHexes, tRegion.id)
		end

		self.wndZoneMap:HighlightRegionsByType(self.eObjectTypeNemesisRegion)
	end
end

function ZoneMap:OnMissionsUncheck(wndHandler, wndControl)
	if wndControl ~= nil then  -- nil if coming from map change
		self.tToggledIcons.bMissions = false
	end

	self.wndZoneMap:HideObjectsByType(self.eObjectTypeMission)
	self.wndZoneMap:RemoveRegionByType(self.eObjectTypeMission)
end

function ZoneMap:OnChallengesUncheck(wndHandler, wndControl)
	if wndControl ~= nil then  -- nil if coming from map change
		self.tToggledIcons.bChallenges = false
	end

	self.wndZoneMap:HideObjectsByType(self.eObjectTypeChallenge)
	self.wndZoneMap:RemoveRegionByType(self.eObjectTypeChallenge)
	self.tChallengeObjects = {}
end

function ZoneMap:OnPublicEventsUncheck(wndHandler, wndControl)
	if wndControl ~= nil then  -- nil if coming from map change
		self.tToggledIcons.bPublicEvents = false
	end

	self.wndZoneMap:HideObjectsByType(self.eObjectTypePublicEvent)
	self.wndZoneMap:RemoveRegionByType(self.eObjectTypePublicEvent)
end

function ZoneMap:OnNemesisRegionsUncheck(wndHandler, wndControl)
	if wndControl ~= nil then  -- nil if coming from map change
		self.tToggledIcons.bNemesisRegions = false
	end

	self.wndZoneMap:HideObjectsByType(self.eObjectTypeNemesisRegion)
	self.wndZoneMap:RemoveRegionByType(self.eObjectTypeNemesisRegion)
end

function ZoneMap:RehideAllToggledIcons()
	if self.wndZoneMap ~= nil and self.tButtonChecks ~= nil then
		for eType, bState in pairs(self.tButtonChecks) do
			if not bState then
				if eType == ktMarkerCategories.QuestNPCs then
					self:SetTypeVisibility(self.eObjectTypeQuestReward, false)
					self:SetTypeVisibility(self.eObjectTypeQuestReceiving, false)
					self:SetTypeVisibility(self.eObjectTypeQuestNew, false)
					self:SetTypeVisibility(self.eObjectTypeQuestNewTradeskill, false)
					self:SetTypeVisibility(self.eObjectTypeQuestNewSoon, false)
					self:SetTypeVisibility(self.eObjectTypeQuestTarget, false)
				elseif eType == ktMarkerCategories.TrackedQuests then
					self.tToggledIcons.bTracked = false
					self:AddQuestIndicators()
					self:UpdateQuestList()
				elseif eType == ktMarkerCategories.Missions then
					self:OnMissionsUncheck()
				elseif eType == ktMarkerCategories.Challenges then
					self:OnChallengesUncheck()
				elseif eType == ktMarkerCategories.PublicEvents then
					self:OnPublicEventsUncheck()
				elseif eType == ktMarkerCategories.Tradeskills then
					self:SetTypeVisibility(self.eObjectTypeTradeskills, false)
				elseif eType == ktMarkerCategories.Vendors then
					self:SetTypeVisibility(self.eObjectTypeVendor, false)
				elseif eType == ktMarkerCategories.Services then
					self:SetTypeVisibility(self.eObjectTypeCommodity, false)
					self:SetTypeVisibility(self.eObjectTypeAuctioneer, false)
					self:SetTypeVisibility(self.eObjectTypeCostume, false)
					self:SetTypeVisibility(self.eObjectTypeBank, false)
					self:SetTypeVisibility(self.eObjectTypeGuildBank, false)
					self:SetTypeVisibility(self.eObjectTypeGuildRegistrar, false)
					self:SetTypeVisibility(self.eObjectTypeCREDDExchange, false)
					self:SetTypeVisibility(self.eObjectTypeMail, false)
					self:SetTypeVisibility(self.eObjectTypeConvert, false)
				elseif eType == ktMarkerCategories.Portals then
					self:SetTypeVisibility(self.eObjectTypeInstancePortal, false)
				elseif eType == ktMarkerCategories.BindPoints then
					self:SetTypeVisibility(self.eObjectTypeBindPointActive, false)
					self:SetTypeVisibility(self.eObjectTypeBindPointInactive, false)
				elseif eType == ktMarkerCategories.GroupObjectives then
					self.tToggledIcons.bGroupObjectives = false
				elseif eType == ktMarkerCategories.MiningNodes then
					self:SetTypeVisibility(self.eObjectTypeMiningNode, false)
				elseif eType == ktMarkerCategories.RelicNodes then
					self:SetTypeVisibility(self.eObjectTypeRelicHunterNode, false)
				elseif eType == ktMarkerCategories.SurvivalistNodes then
					self:SetTypeVisibility(self.eObjectTypeSurvivalistNode, false)
				elseif eType == ktMarkerCategories.FarmingNodes then
					self:SetTypeVisibility(self.eObjectTypeFarmingNode, false)
				elseif eType == ktMarkerCategories.NemesisRegions then
					self:SetTypeVisibility(self.eObjectTypeNemesisRegion, false)
				elseif eType == ktMarkerCategories.Taxis then
					self:SetTypeVisibility(self.eObjectTypeVendorFlightPathNew, false)
					self:SetTypeVisibility(self.eObjectTypeVendorFlight, false)
				elseif eType == ktMarkerCategories.CityDirections then
					self:SetTypeVisibility(self.eObjectCityDirections, false)
				end
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Icons
-----------------------------------------------------------------------------------------------

function ZoneMap:OnUnitChanged(unitUpdated, eType)
	if unitUpdated == nil then
		return
	end

	self.wndZoneMap:RemoveUnit(unitUpdated)
	self.tUnitsShown[unitUpdated:GetId()] = nil
	self.tUnitsHidden[unitUpdated:GetId()] = nil
	self:OnUnitCreated(unitUpdated)
end

function ZoneMap:OnUnitDestroyed(unitDead)
	self.tUnitsShown[unitDead:GetId()] = nil
	self.tUnitsHidden[unitDead:GetId()] = nil

	if unitDead:IsInYourGroup() then
		for idxMember = 2, GroupLib.GetMemberCount() do
			local unitMember = GroupLib.GetUnitForGroupMember(idxMember)
			if unitMember == unitDead then
				local tMember = self.tGroupMembers[idxMember]
				if tMember ~= nil then
					tMember.tWorldLoc = unitDead:GetPosition()
					self:DrawGroupMember(tMember)
				end
				break
			end
		end
	end
end

function ZoneMap:IsTypeCurrentlyHidden(objectType)
	local eZoomLevel = self.wndZoneMap:GetDisplayMode()
	if eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.SuperPanning then
		for i, type in pairs(self.arShownTypesSuperPanning) do
			if objectType == type then
				return false
			end
		end
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Panning then
		for i, type in pairs(self.arShownTypesPanning) do
			if objectType == type then
				return false
			end
		end
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Scaled then
		for i, type in pairs(self.arShownTypesScaled) do
			if objectType == type then
				return false
			end
		end
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.Continent then
		for i, type in pairs(self.arShownTypesContinent) do
			if objectType == type then
				return false
			end
		end
	elseif eZoomLevel == ZoneMapWindow.CodeEnumDisplayMode.World then
		for i, type in pairs(self.arShownTypesWorld) do
			if objectType == type then
				return false
			end
		end
	end
	return true
end

function ZoneMap:GetDefaultUnitInfo()
	local tInfo =
	{
		strIcon 		= "",
		strIconEdge 	= "",
		crObject 		= CColor.new(1, 1, 1, 1),
		crEdge 			= CColor.new(1, 1, 1, 1),
		bAboveOverlay 	= false,
	}
	return tInfo
end

function ZoneMap:GetOrderedMarkerInfos(tMarkerStrings)
	local tMarkerInfos = {}
	for nMarkerIdx, strMarker in ipairs(tMarkerStrings) do
		if strMarker then
			local tMarkerOverride = self.tMinimapMarkerInfo[strMarker]
			if tMarkerOverride then
				table.insert(tMarkerInfos, tMarkerOverride)
			end
		end
	end

	table.sort(tMarkerInfos, function(x, y) return x.nOrder < y.nOrder end)
	return tMarkerInfos
end

function ZoneMap:OnUnitCreated(unitMade)
	if unitMade == nil or not unitMade:IsValid() or unitMade == GameLib.GetPlayerUnit() then
		return
	end
	self.tUnitCreateQueue[#self.tUnitCreateQueue + 1] = unitMade
end

function ZoneMap:OnUnitCreateDelayTimer()
	local nCurrentTime = os.time()

	while #self.tUnitCreateQueue > 0 do
		local unit = table.remove(self.tUnitCreateQueue, #self.tUnitCreateQueue)
		if unit:IsValid() then
			self:OnUnitDelayedCreated(unit)
		end

		if os.time() - nCurrentTime > 0 then
			break
		end
	end
end

function ZoneMap:OnUnitDelayedCreated(unitMade)
	if unitMade == nil or not unitMade:IsValid() then
		return
	end

	local bShowUnit = unitMade:IsVisibleOnCurrentZoneMinimap()

	if bShowUnit == false then
		self.tUnitsHidden[unitMade:GetId()] = { unitValue = unitMade } -- valid, but different subzone. Add it to the list
		return
	end

	local tMarkers = unitMade:GetMiniMapMarkers()
	if tMarkers == nil then
		return
	end

	local tMarkerInfoList = self:GetOrderedMarkerInfos(tMarkers)
	for nIdx, tMarkerInfo in ipairs(tMarkerInfoList) do
		local tInfo = self:GetDefaultUnitInfo()
		local tInteract = unitMade:GetActivationState()
		if tMarkerInfo.strIcon then
			tInfo.strIcon = tMarkerInfo.strIcon
		end
		if tMarkerInfo.crObject then
			tInfo.crObject = tMarkerInfo.crObject
		end
		if tMarkerInfo.crEdge   then
			tInfo.crEdge = tMarkerInfo.crEdge
		end

		local tMarkerOptions = {bNeverShowOnEdge = true}
		if tMarkerInfo.bAboveOverlay then
			tMarkerOptions.bAboveOverlay = tMarkerInfo.bAboveOverlay
		end
		if tMarkerInfo.bShown then
			tMarkerOptions.bShown = tMarkerInfo.bShown
		end
		-- only one of these should be set
		if tMarkerInfo.bFixedSizeSmall then
			tMarkerOptions.bFixedSizeSmall = tMarkerInfo.bFixedSizeSmall
		elseif tMarkerInfo.bFixedSizeMedium then
			tMarkerOptions.bFixedSizeMedium = tMarkerInfo.bFixedSizeMedium
		end

		local objectType = GameLib.CodeEnumMapOverlayType.Unit
		if tMarkerInfo.objectType then
			objectType = tMarkerInfo.objectType
		end

		if not tInteract.Busy and (not tMarkerInfo.bHideIfHostile
			or (tMarkerInfo.bHideIfHostile and unitMade:GetDispositionTo(GameLib.GetPlayerUnit()) ~= Unit.CodeEnumDisposition.Hostile)) then
			local mapIconReference = self.wndZoneMap:AddUnit(unitMade, objectType, tInfo, tMarkerOptions, self:IsTypeCurrentlyHidden(objectType))
			self.tUnitsShown[unitMade:GetId()] = { unitValue = unitMade }

			if objectType == self.eObjectTypeGroupMember then
				for idxMember = 2, GroupLib.GetMemberCount() do
					local unitMember = GroupLib.GetUnitForGroupMember(idxMember)
					if unitMember == unitMade then
						if self.tGroupMembers[idxMember] ~= nil then
							if self.tGroupMembers[idxMember].mapObject ~= nil then
								self.wndZoneMap:RemoveObject(self.tGroupMembers[idxMember].mapObject)
							end
	
							self.tGroupMembers[idxMember].mapObject = mapIconReference
						end
						break
					end
				end
			end
		end

	end
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Challenges
function ZoneMap:OnFailChallenge(tChallengeData)
	self:OnRemoveChallengeIcon(tChallengeData:GetId())
	self:UpdateChallengeList()
end

function ZoneMap:OnRemoveChallengeIcon(idChallenge)
	if self.tChallengeObjects[idChallenge] ~= nil then
		self.wndZoneMap:RemoveObjectsByUserData(self.eObjectTypeChallenge, self.tChallengeObjects[idChallenge])
		self.wndZoneMap:RemoveRegionByUserData(self.eObjectTypeChallenge, self.tChallengeObjects[idChallenge])
		self.tChallengeObjects[idChallenge] = nil
	end
end

function ZoneMap:OnAddChallengeIcon(chalCurrent, strPointIcon)
	if not self.tToggledIcons.bChallenges then
		return
	end

	local idChallenge = chalCurrent:GetId()
	self:OnRemoveChallengeIcon(idChallenge)

	self.tChallengeObjects[idChallenge] = chalCurrent

	local tRegionList = chalCurrent:GetMapRegions()
	for nRgnIdx, tRegion in pairs(tRegionList) do
		self.wndZoneMap:AddRegion(self.eObjectTypeChallenge, 0, tRegion.tHexes, chalCurrent, tRegion.tIndicator)
	end
end

function ZoneMap:OnFlashChallengeIcon(idChallenge, strDescription, fDuration, tPosition)
	local chalCurr = self.tChallengeObjects[idChallenge]
	if challenge == nil then
		return
	end

	self:OnRemoveChallengeIcon(idChallenge)

	if self.tToggledIcons.bChallenges ~= false then
		self:OnAddChallengeIcon(chalCurr, "Icon_MapNode_Map_Generic_POI")
		self.idChallengeFlashingIcon= idChallenge

		-- create the timer to turn off this flashing icon
		Apollo.StopTimer("ChallengeFlashIconTimer")
		Apollo.CreateTimer("ChallengeFlashIconTimer", fDuration, false)
		Apollo.StartTimer("ChallengeFlashIconTimer")
	end
end

function ZoneMap:OnStopChallengeFlashIcon()
	Apollo.StopTimer("ChallengeFlashIconTimer")

	if self.idChallengeFlashingIcon and self.tChallengeObjects[self.idChallengeFlashingIcon] then
		self:OnRemoveChallengeIcon(self.idChallengeFlashingIcon)
	end

	self.idChallengeFlashingIcon = nil
end

function ZoneMap:UpdateChallengeList()
	if self.wndMain == nil then
		-- yes, it is possible for this to be nil here because we might not have gotten the OnLoad event yet
		return
	end

	self.wndMapControlPanel:FindChild("ChallengePaneContentList"):DestroyChildren()

	local tChallengeList = ChallengesLib:GetActiveChallengeList()

	local nCount = 0
	for id, chalCurrent in pairs(tChallengeList) do
		if chalCurrent:IsActivated() then
			local wndLine = Apollo.LoadForm(self.xmlDoc, "ChallengeEntry", self.wndMapControlPanel:FindChild("ChallengePaneContentList"), self)
			local wndNumber = wndLine:FindChild("TextNumber")

			-- number the queCurr
			nCount = nCount + 1
			wndNumber:SetText(String_GetWeaselString(Apollo.GetString("ZoneMap_TextNumber"), nCount))
			wndNumber:SetTextColor(kcrQuestNumberColor)

			wndLine:FindChild("TextNoItem"):Enable(false)

			local strTitle = string.format("<P Font=\"%s\" TextColor=\"%s\">%s</P>", kstrQuestFont, kstrQuestNameColor, chalCurrent:GetName())

			wndLine:FindChild("TextNoItem"):SetAML(strTitle)
			wndLine:FindChild("ChallengeBacker"):SetBGColor(CColor.new(1,1,1,0.5))
			wndLine:SetData(chalCurrent)

			local nTextWidth, nTextHeight = wndLine:FindChild("TextNoItem"):SetHeightToContentHeight()
			local nLeft, nTop, nRight, nBottom = wndLine:GetAnchorOffsets()
			wndLine:SetAnchorOffsets(nLeft, nTop, nRight, 10 + math.max(knQuestItemHeight, nTextHeight))
		end
	end

	self.wndMapControlPanel:FindChild("ChallengePaneContentList"):ArrangeChildrenVert(0)
end

function ZoneMap:ChallengeEntryMouseEnter( wndHandler, wndControl, x, y )
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	wndControl:FindChild("ChallengeBacker"):SetBGColor(CColor.new(1,1,1,1))

	self:SetHoverRegion(wndControl:GetData())
end

function ZoneMap:ChallengeEntryMouseExit( wndHandler, wndControl, x, y )
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	wndControl:FindChild("ChallengeBacker"):SetBGColor(CColor.new(1,1,1,0.5))

	self:ClearHoverRegion(wndControl:GetData())
end

function ZoneMap:ChallengeEntryMouseButtonDown( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	self:ToggleActiveRegion(wndControl:GetData())
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Missions
function ZoneMap:OnPlayerPathMissionActivate(pmActivated)
	if not self.tToggledIcons.bMissions then
		return
	end

	self:OnPlayerPathMissionDeactivate(pmActivated)

	local tRegionList = pmActivated:GetMapRegions()
	for nRgnIdx, tRegion in pairs(tRegionList) do
		self.wndZoneMap:AddRegion(self.eObjectTypeMission, 0, tRegion.tHexes, pmActivated, tRegion.tIndicator)
	end
end

function ZoneMap:OnPlayerPathMissionDeactivate(pmEnded)
	self.wndZoneMap:RemoveObjectsByUserData(self.eObjectTypeMission, pmEnded)
	self.wndZoneMap:RemoveRegionByUserData(self.eObjectTypeMission, pmEnded)
	self:UpdateMissionList()
end

function ZoneMap:UpdateMissionList()
	if self.wndMain == nil then
		-- yes, it is possible for this to be nil here because we might not have gotten the OnLoad event yet
		return
	end

	self.wndMapControlPanel:FindChild("MissionPaneContentList"):DestroyChildren()
	local epiPathEpisode = PlayerPathLib.GetCurrentEpisode()
	if epiPathEpisode == nil then
		return
	end

	local tMissionList = epiPathEpisode:GetMissions()

	local nCount = 0
	for idx, pmCurrent in ipairs(tMissionList) do
		local state = pmCurrent:GetMissionState()
		if state == PathMission.PathMissionState_Unlocked or state == PathMission.PathMissionState_Started then
			local wndMissionLine = Apollo.LoadForm(self.xmlDoc, "MissionEntry", self.wndMapControlPanel:FindChild("MissionPaneContentList"), self)
			local wndNumber = wndMissionLine:FindChild("TextNumber")


			-- number the queCurr
			nCount = nCount + 1
			wndNumber:SetText(String_GetWeaselString(Apollo.GetString("ZoneMap_TextNumber"), nCount))
			wndNumber:SetTextColor(kcrQuestNumberColor)

			wndMissionLine:FindChild("TextNoItem"):Enable(false)

			local strMissionTitle = string.format("<P Font=\"%s\" TextColor=\"%s\">%s</P>", kstrQuestFont, kstrQuestNameColor, pmCurrent:GetName())

			wndMissionLine:FindChild("TextNoItem"):SetAML(strMissionTitle)
			wndMissionLine:FindChild("MissionBacker"):SetBGColor(CColor.new(1,1,1,0.5))
			wndMissionLine:SetData(pmCurrent)

			local nQuestTextWidth, nQuestTextHeight = wndMissionLine:FindChild("TextNoItem"):SetHeightToContentHeight()
			local nLeft, nTop, nRight, nBottom = wndMissionLine:GetAnchorOffsets()
			wndMissionLine:SetAnchorOffsets(nLeft, nTop, nRight, 10 + math.max(knQuestItemHeight, nQuestTextHeight))
		end
	end

	self.wndMapControlPanel:FindChild("MissionPaneContentList"):ArrangeChildrenVert(0)
end

function ZoneMap:MissionEntryMouseEnter( wndHandler, wndControl, x, y )
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	wndControl:FindChild("MissionBacker"):SetBGColor(CColor.new(1,1,1,1))

	self:SetHoverRegion(wndControl:GetData())
end

function ZoneMap:MissionEntryMouseExit( wndHandler, wndControl, x, y )
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	wndControl:FindChild("MissionBacker"):SetBGColor(CColor.new(1,1,1,0.5))

	self:ClearHoverRegion(wndControl:GetData())
end

function ZoneMap:MissionEntryMouseButtonDown( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	self:ToggleActiveRegion(wndControl:GetData())
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Public events
function ZoneMap:OnPublicEventUpdate(peUpdated)
	if not self.tToggledIcons.bPublicEvents then
		return
	end

	self:OnPublicEventCleared(peUpdated)

	local tRegionList = peUpdated:GetMapRegions()
	for nRgnIdx, tRegion in pairs(tRegionList) do
		self.wndZoneMap:AddRegion(self.eObjectTypePublicEvent, 0, tRegion.tHexes, peUpdated, tRegion.tIndicator)
	end

	if peUpdated:IsActive() then
		for idx, peoCurrent in ipairs(peUpdated:GetObjectives()) do
			self:OnPublicEventObjectiveUpdate(peoCurrent)
		end
	end
end

function ZoneMap:OnPublicEventCleared(peCurrent)
	self.wndZoneMap:RemoveObjectsByUserData(self.eObjectTypePublicEvent, peCurrent)
	self.wndZoneMap:RemoveRegionByUserData(self.eObjectTypePublicEvent, peCurrent)

	for key, peoCurr in pairs(peCurrent:GetObjectives()) do
		self:OnPublicEventObjectiveEnd(peoCurr)
	end
end

function ZoneMap:OnPublicEventEnd(peEnding, eReason, tEventInfo)
	self.wndZoneMap:RemoveObjectsByUserData(self.eObjectTypePublicEvent, peEnding)
	self.wndZoneMap:RemoveRegionByUserData(self.eObjectTypePublicEvent, peEnding)

	for key, peoCurr in pairs(peEnding:GetObjectives()) do
		self:OnPublicEventObjectiveEnd(peoCurr)
	end
end

function ZoneMap:OnPublicEventObjectiveUpdate(peoUpdated)
	if not self.tToggledIcons.bPublicEvents then
		return
	end

	self:UpdateCurrentZone()

	self:OnPublicEventObjectiveEnd(peoUpdated)

	if peoUpdated:GetStatus() ~= PublicEventObjective.PublicEventStatus_Active then
		return
	end

	local tRegionList = peoUpdated:GetMapRegions()
	for nRgnIdx, tRegion in pairs(tRegionList) do
		self.wndZoneMap:AddRegion(self.eObjectTypePublicEvent, tRegion.nWorldZoneId, tRegion.tHexes, peoUpdated, tRegion.tIndicator)
	end

	self.wndZoneMap:HighlightRegionsByUserData(peoUpdated)
end

function ZoneMap:OnPublicEventObjectiveEnd(peoEnding)
	self.wndZoneMap:RemoveObjectsByUserData(self.eObjectTypePublicEvent, peoEnding)
	self.wndZoneMap:RemoveRegionByUserData(self.eObjectTypePublicEvent, peoEnding)
end

function ZoneMap:OnMapPulseTimer()
	if self.wndMain:IsShown() then
		if self.arPulses == nil then
			return
		end

		local tDeadPulses = {}
		for key, tPulse in pairs(self.arPulses) do
			local fRadius = self.wndZoneMap:GetObjectRadius(tPulse.id)
			if fRadius >= 4000 then
				self.wndZoneMap:RemoveObject(tPulse.id)
				tDeadPulses[tPulse.id] = tPulse.id
			else
				self.wndZoneMap:SetObjectRadius(tPulse.id, fRadius + 2000.0 * fElapsed)
			end
		end
	end
end

function ZoneMap:UpdatePublicEventList()
	if self.wndMain == nil then
		-- yes, it is possible for this to be nil here because we might not have gotten the OnLoad event yet
		return
	end

	self.wndMapControlPanel:FindChild("PublicEventPaneContentList"):DestroyChildren()

	local tEventList = PublicEventsLib.GetActivePublicEventList()

	local nCount = 0
	for id, peCurrent in pairs(tEventList) do
		if peCurrent:IsActive() then
			local wndLine = Apollo.LoadForm(self.xmlDoc, "PublicEventEntry", self.wndMapControlPanel:FindChild("PublicEventPaneContentList"), self)
			local wndNumber = wndLine:FindChild("TextNumber")

			-- number the queCurr
			nCount = nCount + 1
			wndNumber:SetText(String_GetWeaselString(Apollo.GetString("ZoneMap_TextNumber"), nCount))
			wndNumber:SetTextColor(kcrQuestNumberColor)

			wndLine:FindChild("TextNoItem"):Enable(false)

			local strTitle = string.format("<P Font=\"%s\" TextColor=\"%s\">%s</P>", kstrQuestFont, kstrQuestNameColor, peCurrent:GetName())

			wndLine:FindChild("TextNoItem"):SetAML(strTitle)
			wndLine:FindChild("PublicEventBacker"):SetBGColor(CColor.new(1,1,1,0.5))
			wndLine:SetData(peCurrent)

			local nTextWidth, nTextHeight = wndLine:FindChild("TextNoItem"):SetHeightToContentHeight()
			local nLeft, nTop, nRight, nBottom = wndLine:GetAnchorOffsets()
			wndLine:SetAnchorOffsets(nLeft, nTop, nRight, 10 + math.max(knQuestItemHeight, nTextHeight))
		end
	end

	self.wndMapControlPanel:FindChild("PublicEventPaneContentList"):ArrangeChildrenVert(0)
end

function ZoneMap:PublicEventEntryMouseEnter( wndHandler, wndControl, x, y )
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	wndControl:FindChild("PublicEventBacker"):SetBGColor(CColor.new(1,1,1,1))

	self:SetHoverRegion(wndControl:GetData())
end

function ZoneMap:PublicEventEntryMouseExit( wndHandler, wndControl, x, y )
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	wndControl:FindChild("PublicEventBacker"):SetBGColor(CColor.new(1,1,1,0.5))
end

function ZoneMap:PublicEventEntryMouseButtonDown( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	self:ToggleActiveRegion(wndControl:GetData())
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- GROUP FUNCTIONS
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

function ZoneMap:OnGroupJoin()
	for idx = 2, GroupLib.GetMemberCount() do
		local tInfo = GroupLib.GetGroupMember(idx)
		if tInfo.bIsOnline then
			self.tGroupMembers[idx] =
			{
				nIndex = idx,
				strName = tInfo.strCharacterName,
			}

			local unitMember = GroupLib.GetUnitForGroupMember(idx)
			if unitMember ~= nil and unitMember:IsValid() then
				self.tUnitCreateQueue[#self.tUnitCreateQueue + 1] = unitMember
			end
		end
	end
end

function ZoneMap:OnGroupAdd(strName)
	for idx = 2, GroupLib.GetMemberCount() do
		local tInfo = GroupLib.GetGroupMember(idx)
		if tInfo.bIsOnline and strName == tInfo.strCharacterName then
			self.tGroupMembers[idx] =
			{
				nIndex = idx,
				strName = tInfo.strCharacterName,
			}

			local unitMember = GroupLib.GetUnitForGroupMember(idx)
			if unitMember ~= nil and unitMember:IsValid() then
				self.tUnitCreateQueue[#self.tUnitCreateQueue + 1] = unitMember
			end

			return
		end
	end
end

function ZoneMap:OnGroupRemove(strName, eReason)
	for idx, tMember in pairs(self.tGroupMembers) do -- remove all of the group objects
		self.wndZoneMap:RemoveObject(tMember.mapObject)
	end

	for idx = 2, GroupLib.GetMemberCount() do
		local tInfo = GroupLib.GetGroupMember(idx)
		if tInfo.bIsOnline and strName ~= tInfo.strCharacterName then
			local unitMember = GroupLib.GetUnitForGroupMember(idx)
			if unitMember ~= nil and unitMember:IsValid() then
				self.tUnitCreateQueue[#self.tUnitCreateQueue + 1] = unitMember
			end
		end
	end

	self:DrawGroupMembers()
end

function ZoneMap:OnGroupLeft(eReason)
	for idx, tMember in pairs(self.tGroupMembers) do -- remove all of the group objects
		self.wndZoneMap:RemoveObject(tMember.mapObject)
	end

	self.tGroupMembers = {}
end

function ZoneMap:OnGroupUpdatePosition(arMembers)
	for idx, tMember in pairs(arMembers) do
		if tMember.nIndex ~= 1 then -- this is the player
			local tMemberInfo = GroupLib.GetGroupMember(tMember.nIndex)
			if self.tGroupMembers[tMember.nIndex] == nil then
				local tInfo =
				{
					nIndex = tMember.nIndex,
					tZoneMap = tMember.tZoneMap,
					idWorld = tMember.idWorld,
					tWorldLoc = tMember.tWorldLoc,
					bInCombatPvp = tMember.bInCombatPvp,
					strName = tMemberInfo.strCharacterName,
				}

				self.tGroupMembers[tMember.nIndex] = tInfo
			else
				self.tGroupMembers[tMember.nIndex].tZoneMap = tMember.tZoneMap
				self.tGroupMembers[tMember.nIndex].tWorldLoc = tMember.tWorldLoc
				self.tGroupMembers[tMember.nIndex].strName = tMemberInfo.strCharacterName
				self.tGroupMembers[tMember.nIndex].idWorld = tMember.idWorld
				self.tGroupMembers[tMember.nIndex].bInCombatPvp = tMember.bInCombatPvp
			end
		end
	end

	self:DrawGroupMembers()
end

function ZoneMap:DrawGroupMembers()
	for idx = 2, GroupLib.GetMemberCount() do
		local tMember = self.tGroupMembers[idx]
		local unitMember = GroupLib.GetUnitForGroupMember(idx)
		if unitMember == nil or not unitMember:IsValid() then
			self:DrawGroupMember(self.tGroupMembers[idx])
		end
	end
end

function ZoneMap:DrawGroupMember(tMember)
	if tMember == nil or tMember.tWorldLoc == nil then
		return
	end

	if tMember.mapObject ~= nil then
		self.wndZoneMap:RemoveObject(tMember.mapObject)
	end

	if not GroupLib.GetGroupMember(tMember.nIndex).bIsOnline then
		return
	end

	local tInfo = {}
	tInfo.strIcon = "IconSprites:Icon_MapNode_Map_GroupMember"
	local bNeverShowOnEdge = true
	if tMember.bInCombatPvp then
		tInfo.strIconEdge	= "sprMM_Group"
		tInfo.crObject		= CColor.new(0, 1, 0, 1)
		tInfo.crEdge 		= CColor.new(0, 1, 0, 1)
		bNeverShowOnEdge = false
	else
		tInfo.strIconEdge	= ""
		tInfo.crObject 		= CColor.new(1, 1, 1, 1)
		tInfo.crEdge 		= CColor.new(1, 1, 1, 1)
		bNeverShowOnEdge = true
	end

	local strNameFormatted = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"ff31fcf6\">%s</T>", tMember.strName)
	strNameFormatted = String_GetWeaselString(Apollo.GetString("ZoneMap_AppendGroupMemberLabel"), strNameFormatted)
	tMember.mapObject = self.wndZoneMap:AddObject(self.eObjectTypeGroupMember, tMember.tWorldLoc, strNameFormatted, tInfo, {bNeverShowOnEdge = bNeverShowOnEdge, bFixedSizeLarge = true})
end

-----------------------------------------------------------------------------------------
-- ZoneMap Mouse Move and Click
-----------------------------------------------------------------------------------------

function ZoneMap:OnZoneMapButtonDown(wndHandler, wndControl, eButton, nX, nY, bDoubleClick) -- TODO: Bulletproof this
	local newActiveRegionUserData = nil
	if self.objActiveRegionUserData ~= nil then
		for hoverIdx, hoverData in pairs(self.arHoverRegionUserDataList) do
			if self.objActiveRegionUserData == hoverData then
				self.objActiveRegionUserData = nil
			else
				newActiveRegionUserData = hoverData
			end
		end
	elseif #self.arHoverRegionUserDataList > 0 then
		newActiveRegionUserData = self.arHoverRegionUserDataList[1]
	end

	self.wndZoneMap:UnhighlightRegionsByUserData(self.objActiveRegionUserData)
	self.objActiveRegionUserData = newActiveRegionUserData
end

function ZoneMap:OnZoneMapMouseMove(wndHandler, wndControl, nX, nY)
	if wndHandler ~= wndControl then
		return
	end

	self:OnGenerateTooltip(wndHandler, wndControl, Tooltip.TooltipGenerateType_Default, nX, nY)

	if not self.bMapCoordinateDelay then
		self.bMapCoordinateDelay = true
		Apollo.StartTimer("ZoneMap_MapCoordinateDelay")

		local tPoint = self.wndZoneMap:WindowPointToClientPoint(nX, nY)
		local tWorldLoc = self.wndZoneMap:GetWorldLocAtPoint(tPoint.x, tPoint.y)
		local nLocX = math.floor(tWorldLoc.x + .5)
		local nLocZ = math.floor(tWorldLoc.z + .5)
		self.wndMain:FindChild("MapCoordinates"):SetText(String_GetWeaselString(Apollo.GetString("ZoneMap_LocationXZ"), nLocX, nLocZ))
	end
	local tHex = self.wndZoneMap:GetHexAtPoint(nX, nY)
	local strZone = tHex.strZone or ""

	local wndTooltip = self.wndZoneMap:FindChild("ZoneName")
	wndTooltip:SetText(strZone)
	if string.len(strZone) > 0 and tHex.nLabelX ~= nil then
		wndTooltip:Move(tHex.nLabelX - 150, tHex.nLabelY - 40, 300, 80)
	end
end

function ZoneMap:OnZoneMap_MapCoordinateDelay()
	Apollo.StopTimer("ZoneMap_MapCoordinateDelay")
	self.bMapCoordinateDelay = false
end

-----------------------------------------------------------------------------------------
-- City Map Marking
-----------------------------------------------------------------------------------------

function ZoneMap:OnCityDirectionsList(tDirections)
	if self.wndCityDirections ~= nil and self.wndCityDirections:IsValid() then
		self.wndCityDirections:Destroy()
	end

	self.wndCityDirections = Apollo.LoadForm(self.xmlDoc, "CityDirections", nil, self)
	self.wndCityDirections:ToFront()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndCityDirections, strName = Apollo.GetString("ZoneMap_CityDirections")})

	local wndCityDirectionsList = self.wndCityDirections:FindChild("CityDirectionsList")
	table.sort(tDirections, function(a, b) return a.strName < b.strName end)

	for idx, tCurrDirection in pairs(tDirections) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "CityDirectionsBtn", wndCityDirectionsList, self)
		wndCurr:FindChild("CityDirectionsBtnIcon"):SetSprite(karCityDirectionsTypeToIcon[tCurrDirection.eType] or "Icon_ArchetypeUI_CRB_DefensiveHealer")
		wndCurr:FindChild("CityDirectionsBtnText"):SetText(tCurrDirection.strName)
		wndCurr:SetData(tCurrDirection.idDestination)
	end

	self.wndCityDirections:FindChild("CityDirectionsList"):ArrangeChildrenVert(0)
end

function ZoneMap:OnCityDirectionsClosed(wndHandler, wndControl)
	Event_CancelCityDirections()
	self.wndCityDirections:Destroy()
end

function ZoneMap:OnCityDirectionBtn(wndHandler, wndControl)
	GameLib.MarkCityDirection(wndHandler:GetData())
	self.wndCityDirections:Destroy()
end

function ZoneMap:OnCityDirectionMarked(tLocInfo)
	if not self.wndZoneMap or not self.wndZoneMap:IsValid() then
		return
	end

	local strCityDirections = Apollo.GetString("ZoneMap_CityDirections")
	local tInfo =
	{
		strIconEdge = "",
		strIcon 	= "sprMM_QuestZonePulse",
		crObject 	= CColor.new(1, 1, 1, 1),
		crEdge 		= CColor.new(1, 1, 1, 1),
	}

	-- Only one city direction at a time, so stomp and remove and previous
	self.wndZoneMap:RemoveObjectsByUserData(self.eObjectTypeCityDirectionPing, strCityDirections)
	self.wndZoneMap:AddObject(self.eObjectTypeCityDirectionPing, tLocInfo.tLoc, tLocInfo.strName, tInfo, {bFixedSizeSmall = false}, false, strCityDirections)
	Apollo.StartTimer("ZoneMap_TimeOutCityDirectionMarker")
	Apollo.StartTimer("ZoneMap_PollCityDirectionsMarker")
	self.tCityDirectionsLoc = tLocInfo.tLoc

	if not self.wndMain:IsVisible() then
		self:ToggleWindow()
	end

	self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Scaled)
	self:SetControls()
	self:OnZoomChange()
end

function ZoneMap:OnZoneMap_PollCityDirectionsMarker()
	-- Wipe city directions if near it (GOTCHA: We don't care about Y)
	if self.tCityDirectionsLoc then
		local unitPlayer = GameLib.GetPlayerUnit()
		if unitPlayer then
			local tPosPlayer = unitPlayer:GetPosition()
			if math.abs(self.tCityDirectionsLoc.x - tPosPlayer.x) < 9 and math.abs(self.tCityDirectionsLoc.z - tPosPlayer.z) < 9 then
				self:OnZoneMap_TimeOutCityDirectionMarker()
			end
		end
	end
end

function ZoneMap:OnZoneMap_TimeOutCityDirectionMarker()
	self.tCityDirectionsLoc = nil
	Apollo.StopTimer("ZoneMap_PollCityDirectionsMarker")
	Apollo.StopTimer("ZoneMap_TimeOutCityDirectionMarker")
	Event_FireGenericEvent("ZoneMap_TimeOutCityDirectionEvent")
	self.wndZoneMap:RemoveObjectsByUserData(self.eObjectTypeCityDirectionPing, Apollo.GetString("ZoneMap_CityDirections"))
end

-----------------------------------------------------------------------------------------
-- Quest List Functions
-----------------------------------------------------------------------------------------

function ZoneMap:UpdateQuestList()
	if self.wndMain == nil then
		-- yes, it is possible for this to be nil here because we might not have gotten the OnLoad event yet
		return
	end

	if self.bIgnoreQuestStateChanged then
		-- used to prevent errors when setting the active queCurr (auto-toggled)
		return
	end

	self.tEpisodeList = QuestLib.GetTrackedEpisodes(self.bQuestTrackerByDistance)
	self.wndMapControlPanel:FindChild("QuestPaneContentList"):DestroyChildren()

	local nCount = 0
	for idx, epiCurr in ipairs(self.tEpisodeList) do
		for idx2, queCurr in ipairs(epiCurr:GetTrackedQuests(0, self.bQuestTrackerByDistance)) do
			local wndQuestLine = Apollo.LoadForm(self.xmlDoc, "QuestEntry", self.wndMapControlPanel:FindChild("QuestPaneContentList"), self)
			local wndNumber = wndQuestLine:FindChild("TextNumber")

			-- number the queCurr
			nCount = nCount + 1
			wndNumber:SetText(String_GetWeaselString(Apollo.GetString("ZoneMap_TextNumber"), nCount))
			wndNumber:SetTextColor(kcrQuestNumberColor)

			local eQuestState = queCurr:GetState() -- don't show completed or unknown quests
			if eQuestState == Quest.QuestState_Achieved or eQuestState == Quest.QuestState_Botched then
				wndNumber:SetTextColor(CColor.new(47/255, 220/255, 2/255, 1.0))

				--Fail state settings
				if eQuestState == Quest.QuestState_Botched then
					wndNumber:SetTextColor(CColor.new(1.0, 0, 0, 1.0))
					wndNumber:SetText(Apollo.GetString("ZoneMap_FailMarker"))
				end
			end

			wndQuestLine:FindChild("TextNoItem"):Enable(false)
			wndQuestLine:FindChild("TextNoItem"):SetAML(self:BuildQuestTitleString(queCurr))
			wndQuestLine:FindChild("QuestBacker"):SetBGColor(CColor.new(1,1,1,0.5))
			wndQuestLine:SetData(queCurr)

			local nQuestTextWidth, nQuestTextHeight = wndQuestLine:FindChild("TextNoItem"):SetHeightToContentHeight()
			local nLeft, nTop, nRight, nBottom = wndQuestLine:GetAnchorOffsets()
			wndQuestLine:SetAnchorOffsets(nLeft, nTop, nRight, 10 + math.max(knQuestItemHeight, nQuestTextHeight))
		end
	end

	self.wndMapControlPanel:FindChild("QuestPaneContentList"):ArrangeChildrenVert(0)
end

function ZoneMap:BuildQuestTitleString(queCurr)
	local strName = ""
	if queCurr:GetState() == Quest.QuestState_Botched then
		strName = string.format("<T Font=\"%s\" TextColor=\"red\">%s </T>", kstrQuestFont, String_GetWeaselString(Apollo.GetString("CRB_Colon"), Apollo.GetString("CRB_Failed")))
	elseif queCurr:GetState() == Quest.QuestState_Achieved then
		local strAchieved = String_GetWeaselString(Apollo.GetString("CRB_Colon"), Apollo.GetString("CRB_Complete"))
		strName = string.format("<T Font=\"%s\" TextColor=\"%s\">%s </T>", kstrQuestFont, kstrQuestNameColorComplete, strAchieved)
	end

	local strQuestTitle = string.format("<P Font=\"%s\" TextColor=\"%s\">%s</P>", kstrQuestFont, kstrQuestNameColor, queCurr:GetTitle())
	if strQuestTitle ~= "" then
		strQuestTitle = String_GetWeaselString(Apollo.GetString("ZoneMap_MissionTypeName"), strName, strQuestTitle)
	end

	return strQuestTitle
end

---------------------------------------------------------------------------------------------------
function ZoneMap:BuildQuestTooltip(queCurr)
	local strQuestTooltip = ""
	local tQuestObjectives = {}
	local tObjData = queCurr:GetVisibleObjectiveData()
	local eQuestState = queCurr:GetState()

	if tObjData == nil then
		return strQuestTooltip
	end

	if eQuestState == Quest.QuestState_Achieved then
		return strQuestTooltip
	elseif eQuestState == Quest.QuestState_Botched then
		return strQuestTooltip
	end

	for idx, tObjRow in ipairs(tObjData) do -- this is performed per objective, including completed
		local nNeeded = tObjRow.nNeeded
		local nCompleted = tObjRow.nCompleted
		local bComplete = nCompleted >= nNeeded
		local bIsReward = tObjRow.bIsReward
		local strDescription = tObjRow.strDescription

		if tObjRow and not tObjRow.bIsRequired and not bComplete then
			strDescription = String_GetWeaselString(Apollo.GetString("ZoneMap_Optional"), strDescription)
		end

		-- only show incomplete objectives or rewards
		local bIncludeLine = false
		if eQuestState == Quest.QuestState_Achieved then
			bIncludeLine = bIsReward
		elseif eQuestState == Quest.QuestState_Botched then
			bIncludeLine = false;
		else
			bIncludeLine = not bComplete
		end

		if bIncludeLine then
			strDescription = string.format("<T Font=\"CRB_InterfaceMedium\">%s</T>", strDescription)
			if nNeeded > 1 then
				if not bComplete then
					local nObjectiveCount = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrQuestFont, kcrEpisodeColor, String_GetWeaselString(Apollo.GetString("CRB_Brackets"), String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nCompleted, nNeeded)))
					strDescription = String_GetWeaselString(Apollo.GetString("ZoneMap_MissionTypeName"), tostring(nObjectiveCount), strDescription)
				end
			end

			local strDesc = string.format("<P>%s</P>", strDescription)

			if queCurr:IsObjectiveTimed(tObjRow.nIndex) and queCurr:GetState() == Quest.QuestState_Accepted and queCurr:CanCompleteObjective(tObjRow.nIndex) then
				local strTimer = Apollo.GetString("ZoneMap_Timed")
				local strTimerFormatted = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrQuestFont, kcrEpisodeColor, strTimer)
				strDesc = String_GetWeaselString(Apollo.GetString("ZoneMap_MissionTypeName"), strTimerFormatted, strDesc)
			end

			table.insert(tQuestObjectives, strDesc)
		end
	end

	for idx, strObjective in ipairs(tQuestObjectives) do
		if idx == 1 then
			strQuestTooltip = strObjective
		else
			local strObjectiveBreak = string.format("<BR />%s", strObjective)
			strQuestTooltip = String_GetWeaselString(Apollo.GetString("ZoneMap_MissionTypeName"), strQuestTooltip, strObjectiveBreak)
		end
	end

	return strQuestTooltip
end

---------------------------------------------------------------------------------------------------
function ZoneMap:QuestEntryMouseEnter(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	wndControl:FindChild("QuestBacker"):SetBGColor(CColor.new(1,1,1,1))

	self:SetHoverRegion(wndControl:GetData())
end

---------------------------------------------------------------------------------------------------
function ZoneMap:QuestEntryMouseExit(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	wndControl:FindChild("QuestBacker"):SetBGColor(CColor.new(1,1,1,0.5))

	self:ClearHoverRegion(wndControl:GetData())
end

function ZoneMap:QuestEntryMouseButtonDown(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	local queCurr = wndControl:GetData()
	self.bIgnoreQuestStateChanged = true  --Bool used in changing active to mouse-over (as ToggleActive auto-repopulates)
	if self.objActiveRegionUserData == queCurr then
		queCurr:SetActiveQuest(false)
	else
		queCurr:ToggleActiveQuest()
	end
	self:ToggleActiveRegion(wndControl:GetData())
	self.bIgnoreQuestStateChanged = false
end

function ZoneMap:OnZoneMap_OpenMapToQuest(queArg)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.bIgnoreQuestStateChanged = true  --Bool used in changing active to mouse-over (as ToggleActive auto-repopulates)
	if self.objActiveRegionUserData == nil or self.objActiveRegionUserData ~= queArg then
		local tRegions = queArg:GetMapRegions()
		local tQuestLoc = tRegions[1] or nil -- TODO: Just the first region for now, for multi region quests
		if tQuestLoc then
			Event_FireGenericEvent("ToggleZoneMap") -- If no regions, then don't bother opening the map

			local objZoneMap = GameLib.GetZoneMap(tQuestLoc.nWorldId, tQuestLoc.nWorldZoneId, tQuestLoc.tIndicator)
			if objZoneMap then
				self.wndZoneMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Scaled)
				self.wndZoneMap:SetZone(objZoneMap.id)
				self.idCurrentZone = objZoneMap.id
				self:SetControls()
				self:OnZoomChange()
			end
		else
			Event_FireGenericEvent("GenericEvent_SystemChannelMessage", Apollo.GetString("ZoneMap_NoMapDataAvailable"))
		end

		queArg:ToggleActiveQuest()
		self.wndZoneMap:HighlightRegionsByUserData(queArg)
	end
	self.bIgnoreQuestStateChanged = false
end

---------------------------------------------------------------------------------------------------
function ZoneMap:SetHoverRegion(objUserData)
	table.insert(self.arHoverRegionUserDataList, objUserData)
	self.wndZoneMap:HighlightRegionsByUserData(objUserData)
end

function ZoneMap:ClearHoverRegion(objUserData)
	if objUserData == self.objActiveRegionUserData then
		return
	end

	for hoverIdx, hoverData in pairs(self.arHoverRegionUserDataList) do
		if hoverData == objUserData then
			self.wndZoneMap:UnhighlightRegionsByUserData(objUserData)
			self.arHoverRegionUserDataList[hoverIdx] = nil
			return
		end
	end
end

function ZoneMap:ToggleActiveRegion(objUserData)
	if self.objActiveRegionUserData == objUserData then
		self.wndZoneMap:UnhighlightRegionsByUserData(objUserData)
		self.objActiveRegionUserData = nil
	else
		self.wndZoneMap:UnhighlightRegionsByUserData(self.objActiveRegionUserData)
		self.objActiveRegionUserData = objUserData
		self.wndZoneMap:HighlightRegionsByUserData(self.objActiveRegionUserData)
	end
end

---------------------------------------------------------------------------------------------------
function ZoneMap:OnMapTrackedUnitUpdate(idTrackedUnit, tPos)
	tTrackedInfo = GetMapTrackedUnitData(idTrackedUnit)
	if tTrackedInfo == nil then
		return
	end

	local tInfo =
	{
		strIcon 	= tTrackedInfo.iconPath,
		crObject 	= CColor.new(1, 1, 1, 1),
		strIconEdge = "",
		crEdge 		= CColor.new(1, 1, 1, 1),
	}

	self.wndZoneMap:RemoveObjectsByUserData(self.eObjectTypeMapTrackedUnit, idTrackedUnit)
	self.wndZoneMap:AddObject(self.eObjectTypeMapTrackedUnit, tPos, tTrackedInfo.label, tInfo, {bNeverShowOnEdge = true, bFixedSizeSmall = false}, not self.tToggledIcons.bTracked, idTrackedUnit)
end

function ZoneMap:OnMapTrackedUnitDisable(idTrackedUnit)
	self.wndZoneMap:RemoveObjectsByUserData(self.eObjectTypeMapTrackedUnit, idTrackedUnit)
end

---------------------------------------------------------------------------------------------------
function ZoneMap:OnLevelChanged(level)
	if level == nil then
		return
	end

	for key, data in pairs(ktGlobalPortalInfo) do
		local unlock = GameLib.GetLevelUpUnlock(data.unlockEnumId)
		if unlock ~= nil and unlock.nLevel <= level then
			self.wndZoneMap:RemoveObjectsByUserData(self.eObjectTypeInstancePortal, data.unlockEnumId)

			local tInfo = self:GetDefaultUnitInfo()
			tInfo.strIcon = self.tPOITypes[self.eObjectTypeInstancePortal].strSprite
			for idx, worldLocId in pairs(data.worldLocIds) do
				self.wndZoneMap:AddObjectByWorldLocId(self.eObjectTypeInstancePortal, worldLocId, unlock.strDescription, tInfo, {bNeverShowOnEdge = true}, self:IsTypeCurrentlyHidden(self.eObjectTypeInstancePortal), data.unlockEnumId)
			end
		end
	end
end

function ZoneMap:HelperLevelupUnlockGotoMap(idWorldZone)
	if not self.wndMain:IsVisible() then
		self:ToggleWindow()
	end

	self.idCurrentZone = idWorldZone
	self.wndZoneMap:SetZone(self.idCurrentZone)

	local tZoneInfo = self.wndZoneMap:GetZoneInfo()
	if tZoneInfo then
		self.wndMain:FindChild("ZoneComplexToggle"):SetData(tZoneInfo.id)
		self:HelperBuildZoneDropdown(tZoneInfo.continentId)
		self.wndMain:FindChild("ZoneComplexToggle"):SetText(tZoneInfo.strName)
	end
end

function ZoneMap:OnLevelUpUnlock_WorldMapAdventure_Astrovoid()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Illium)
end

function ZoneMap:OnLevelUpUnlock_WorldMapAdventure_Galeras()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Whitevale)
end

function ZoneMap:OnLevelUpUnlock_WorldMapAdventure_Hycrest()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Thayd)
end

function ZoneMap:OnLevelUpUnlock_WorldMapAdventure_Malgrave()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Grimvault)
end

function ZoneMap:OnLevelUpUnlock_WorldMapAdventure_NorthernWilds()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Whitevale)
end

function ZoneMap:OnLevelUpUnlock_WorldMapAdventure_Whitevale()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Wilderrun)
end

function ZoneMap:OnLevelUpUnlock_WorldMapDungeon_UltimateProtogames()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Malgrave)
end

function ZoneMap:OnLevelUpUnlock_WorldMapDungeon_SwordMaiden()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Wilderrun)
end

function ZoneMap:OnLevelUpUnlock_WorldMapDungeon_Skullcano()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Whitevale)
end

function ZoneMap:OnLevelUpUnlock_WorldMapDungeon_KelVoreth()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Auroria)
end

function ZoneMap:OnLevelUpUnlock_WorldMapDungeon_Stormtalon()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Galeras)
end

function ZoneMap:OnLevelUpUnlock_WorldMapDungeon_ProtogamesAcademyExile()
	local tCurrentZoneInto = GameLib.GetCurrentZoneMap()
	if tCurrentZoneInto == nil then
		return
	end
	
	local tZones = ktGlobalPortalInfo.ProtogamesAcademyExile.idZones
	if tZones ~= nil then
		for idx, idZone in pairs(tZones) do
			if tCurrentZoneInto.id == idZone then
				self:HelperLevelupUnlockGotoMap(idZone)
				return
			end
		end
	end
	
	self:HelperLevelupUnlockGotoMap(ktGlobalPortalInfo.ProtogamesAcademyExile.idZones[1])
end

function ZoneMap:OnLevelUpUnlock_WorldMapDungeon_ProtogamesAcademyDominion()
	local tCurrentZoneInto = GameLib.GetCurrentZoneMap()
	if tCurrentZoneInto == nil then
		return
	end
	
	local tZones = ktGlobalPortalInfo.ProtogamesAcademyDominion.idZones
	if tZones ~= nil then
		for idx, idZone in pairs(tZones) do
			if tCurrentZoneInto.id == idZone then
				self:HelperLevelupUnlockGotoMap(idZone)
				return
			end
		end
	end
	
	self:HelperLevelupUnlockGotoMap(ktGlobalPortalInfo.ProtogamesAcademyDominion.idZones[1])
end

function ZoneMap:OnLevelUpUnlock_WorldMapCapital_Thayd()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Thayd)
end

function ZoneMap:OnLevelUpUnlock_WorldMapCapital_Illium()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Illium)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Algoroc()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Algoroc)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Auroria()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Auroria)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Celestion()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Celestion)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_CrimsonIsle()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.CrimsonIsle)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Deradune()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Deradune)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Ellevar()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Ellevar)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_EverstarGrove()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.EverstarGrove)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Farside()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Farside)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Galeras()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Galeras)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Grimvault()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Grimvault)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_LevianBay()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.LevianBay)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Malgrave()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Malgrave)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_NorthernWilds()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.NorthernWilds)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Whitevale()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Whitevale)
end

function ZoneMap:OnLevelUpUnlock_WorldMapNewZone_Wilderrun()
	self:HelperLevelupUnlockGotoMap(GameLib.MapZone.Wilderrun)
end

---------------------------------------------------------------------------------------------------
function ZoneMap:FactoryProduce(wndParent, strFormName, tObject)
	local wndNew = wndParent:FindChildByUserData(tObject)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndNew:SetData(tObject)
	end
	return wndNew
end

local ZoneMap_Singleton = ZoneMap:new()
ZoneMap_Singleton:Init()
ZoneMapLibrary = ZoneMap_Singleton

