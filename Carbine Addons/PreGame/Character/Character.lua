require "Apollo"
require "Window"
require "CharacterScreenLib"
require "PreGameLib"
require "Sound"

---------------------------------------------------------------------------------------------------
-- Character module definition

local Character = {}


LuaEnumState =
{
	Select 		= 1,
	Create 		= 2,
	Delete 		= 3,
	Customize 	= 4,
}

local k_idCassian = 100	-- Humans (Dominion - fabricated value)

local s_isInSelectButtons = false

local c_arRaceStrings =  --inserting values so we can use direct race numbering. Each holds a table with name, then description
{
	[PreGameLib.CodeEnumRace.Human] 		= {"CRB_ExileHuman", 	"CRB_CC_Race_ExileHumans",},
	[PreGameLib.CodeEnumRace.Mordesh] 		= {"CRB_Mordesh", 		"CRB_CC_Race_Mordesh",},
	[PreGameLib.CodeEnumRace.Granok] 		= {"CRB_DemoCC_Granok",	"CRB_CC_Race_Granok",},
	[PreGameLib.CodeEnumRace.Aurin] 		= {"CRB_DemoCC_Aurin",	"CRB_CC_Race_Aurin",},
	[PreGameLib.CodeEnumRace.Draken] 		= {"RaceDraken",		"CRB_CC_Race_Draken",},
	[PreGameLib.CodeEnumRace.Mechari] 		= {"RaceMechari",		"CRB_CC_Race_Mechari",},
	[PreGameLib.CodeEnumRace.Chua] 			= {"RaceChua",			"CRB_CC_Race_Chua",},
	[k_idCassian] 							= {"CRB_Cassian",		"CRB_CC_Race_DominionHumans",},
}

local c_arClassStrings =  --inserting values so we can use direct class numbering. Each holds a table with name, then description
{
	[PreGameLib.CodeEnumClass.Warrior] 		= {"ClassWarrior", 		"CRB_CC_Class_Warrior",},
	[PreGameLib.CodeEnumClass.Engineer] 	= {"ClassEngineer", 	"CRB_CC_Class_Engineer",},
	[PreGameLib.CodeEnumClass.Esper] 		= {"ClassESPER", 		"CRB_CC_Class_Esper",},
	[PreGameLib.CodeEnumClass.Medic] 		= {"ClassMedic", 		"CRB_CC_Class_Medic",},
	[PreGameLib.CodeEnumClass.Stalker] 		= {"ClassStalker", 		"CRB_CC_Class_Stalker",},
	--{"ClassWeaver", 		"CRB_DemoCC_Corrupted_Desc",}, -- Corrupted
	[PreGameLib.CodeEnumClass.Spellslinger] = {"ClassSpellslinger", "CRB_CC_Class_Spellslinger",},
	--{"ClassSorcerer", 		"CRB_DemoCC_DarkWeaver_Desc",}, -- Dark Weaver
	--{"ClassCharmer", 		"CRB_DemoCC_Charmer_Desc",},
}

local c_arRaceButtons =  --inserting values so we can use direct race numbering. Each holds a table with name, then description
{
	[PreGameLib.CodeEnumRace.Human] 		= {male = "CRB_CharacterCreateSprites:btnCharC_RG_HuM_Ex", 	female = "CRB_CharacterCreateSprites:btnCharC_RG_HuF_Ex"},
	[PreGameLib.CodeEnumRace.Mordesh] 		= {male = "CRB_CharacterCreateSprites:btnCharC_RG_MoM", 	female = "CRB_CharacterCreateSprites:btnCharC_RG_MoF"},
	[PreGameLib.CodeEnumRace.Granok] 		= {male = "CRB_CharacterCreateSprites:btnCharC_RG_GrM", 	female = "CRB_CharacterCreateSprites:btnCharC_RG_GrF"},
	[PreGameLib.CodeEnumRace.Aurin] 		= {male = "CRB_CharacterCreateSprites:btnCharC_RG_AuM", 	female = "CRB_CharacterCreateSprites:btnCharC_RG_AuF"},
	[PreGameLib.CodeEnumRace.Draken] 		= {male = "CRB_CharacterCreateSprites:btnCharC_RG_DrM", 	female = "CRB_CharacterCreateSprites:btnCharC_RG_DrF"},
	[PreGameLib.CodeEnumRace.Mechari] 		= {male = "CRB_CharacterCreateSprites:btnCharC_RG_MeM", 	female = "CRB_CharacterCreateSprites:btnCharC_RG_MeF"},
	[PreGameLib.CodeEnumRace.Chua] 			= {male = "CRB_CharacterCreateSprites:btnCharC_RG_Chua"}, -- Chua
	[k_idCassian]	 						= {male = "CRB_CharacterCreateSprites:btnCharC_RG_HuM_Dom", female = "CRB_CharacterCreateSprites:btnCharC_RG_HuF_Dom"},
}

local c_arFactionStrings =
{
	[PreGameLib.CodeEnumFaction.Exile] 		= "CRB_CC_Faction_Exiles",
	[PreGameLib.CodeEnumFaction.Dominion] 	= "CRB_CC_Faction_Dominion",
}

local c_arAllowedRace =
{
	[PreGameLib.CodeEnumRace.Human] 	= true,
	[PreGameLib.CodeEnumRace.Mordesh]	= true,
	[PreGameLib.CodeEnumRace.Granok]	= true,
	[PreGameLib.CodeEnumRace.Aurin] 	= true,
	[PreGameLib.CodeEnumRace.Draken] 	= true,
	[PreGameLib.CodeEnumRace.Mechari] 	= true,
	[PreGameLib.CodeEnumRace.Chua] 		= true,
}


local c_arAllowedClass =
{
	[PreGameLib.CodeEnumClass.Warrior] 		= true,
	[PreGameLib.CodeEnumClass.Engineer] 	= true,
	[PreGameLib.CodeEnumClass.Esper] 		= true,
	[PreGameLib.CodeEnumClass.Medic] 		= true,
	[PreGameLib.CodeEnumClass.Stalker] 		= true,
	[PreGameLib.CodeEnumClass.Spellslinger] = true,
}


local c_arPathStrings =  --paths are sequential but zero-indexed
{
	[PreGameLib.CodeEnumPlayerPathType.Soldier] 	= {"CRB_Soldier", 	"CRB_CC_Path_Soldier"},
	[PreGameLib.CodeEnumPlayerPathType.Settler] 	= {"CRB_Settler", 	"CRB_CC_Path_Settler"},
	[PreGameLib.CodeEnumPlayerPathType.Scientist] 	= {"CRB_Scientist", "CRB_CC_Path_Scientist"},
	[PreGameLib.CodeEnumPlayerPathType.Explorer] 	= {"CRB_Explorer", 	"CRB_CC_Path_Explorer"},
}

local c_SceneTime = 6 * 60 * 60 -- seconds from midnight

local c_defaultRotation = 190 -- sets the initial customize angle
local c_defaultRotationModel = 190

local kiRotateIntervalModel = .05 -- How much does the model rotate when the player holds the arrow. Pulse is set in XML


local kcrNormalBack = "CRB_Basekit:kitBase_HoloBlue_TinyNoGlow"
local kcrSelectedBack = "CRB_Basekit:kitBase_HoloBlue_TinyLitNoGlow"
local kcrNormalButton = "CRB_DEMO_WrapperSprites:btnDemo_CharInvisible"
local kcrSelectedButton = "PlayerPathContent_TEMP:btn_PathListBlueFlyby"

local kstrRealmFullClosed = Apollo.GetString("Pregame_RealmFullClosed")
local kstrRealmFullOpen = Apollo.GetString("Pregame_RealmFullOpen")

local knCheerAnimation = 1621
local knDefaultReady = 150

local c_classSelectAnimation =
{
	[PreGameLib.CodeEnumClass.Spellslinger] = 452,
	[PreGameLib.CodeEnumClass.Stalker] 		= 1151,
	[PreGameLib.CodeEnumClass.Engineer] 	= 707,
	[PreGameLib.CodeEnumClass.Warrior] 		= 94,
	[PreGameLib.CodeEnumClass.Esper] 		= 150,
	[PreGameLib.CodeEnumClass.Medic] 		= 1322,
}

local c_customizePlayerAnimation = 5612

local c_factionPlayerAnimation =
{
	[PreGameLib.CodeEnumFaction.Exile] = 7724,
	[PreGameLib.CodeEnumFaction.Dominion] = 7723,
}

local c_factionIconAnimation =
{
	[PreGameLib.CodeEnumFaction.Exile] = 1118,
	[PreGameLib.CodeEnumFaction.Dominion] = 1120,
}

local c_classIconAnimation =
{
	[PreGameLib.CodeEnumClass.Spellslinger] = 1118,
	[PreGameLib.CodeEnumClass.Stalker] = 1120,
	[PreGameLib.CodeEnumClass.Engineer] = 1122,
	[PreGameLib.CodeEnumClass.Warrior] = 6670,
	[PreGameLib.CodeEnumClass.Esper] = 1109,
	[PreGameLib.CodeEnumClass.Medic] = 1110,
}

local c_pathIconAnimation =
{
	[PreGameLib.CodeEnumPlayerPathType.Explorer] = 1118,
	[PreGameLib.CodeEnumPlayerPathType.Soldier] = 1120,
	[PreGameLib.CodeEnumPlayerPathType.Scientist] = 1122,
	[PreGameLib.CodeEnumPlayerPathType.Settler] = 6670,
}

local c_cameraZoomAnimation = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Human] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Human][PreGameLib.CodeEnumGender.Male] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Human][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Exile] = 7725
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Human][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Dominion] = 7738
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Human][PreGameLib.CodeEnumGender.Female] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Human][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Exile] = 7726
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Human][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Dominion] = 7739

c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Aurin] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Aurin][PreGameLib.CodeEnumGender.Male] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Aurin][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Exile] = 7727
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Aurin][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Dominion] = 7727
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Aurin][PreGameLib.CodeEnumGender.Female] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Aurin][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Exile] = 7728
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Aurin][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Dominion] = 7728

c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Chua] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Chua][PreGameLib.CodeEnumGender.Male] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Chua][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Exile] = 7729
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Chua][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Dominion] = 7729
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Chua][PreGameLib.CodeEnumGender.Female] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Chua][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Exile] = 7729
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Chua][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Dominion] = 7729

c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Draken] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Draken][PreGameLib.CodeEnumGender.Male] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Draken][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Exile] = 7730
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Draken][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Dominion] = 7730
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Draken][PreGameLib.CodeEnumGender.Female] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Draken][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Exile] = 7731
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Draken][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Dominion] = 7731

c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mordesh] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mordesh][PreGameLib.CodeEnumGender.Male] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mordesh][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Exile] = 7732
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mordesh][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Dominion] = 7732
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mordesh][PreGameLib.CodeEnumGender.Female] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mordesh][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Exile] = 7733
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mordesh][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Dominion] = 7733

c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mechari] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mechari][PreGameLib.CodeEnumGender.Male] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mechari][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Exile] = 7734
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mechari][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Dominion] = 7734
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mechari][PreGameLib.CodeEnumGender.Female] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mechari][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Exile] = 7735
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Mechari][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Dominion] = 7735

c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Granok] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Granok][PreGameLib.CodeEnumGender.Male] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Granok][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Exile] = 7736
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Granok][PreGameLib.CodeEnumGender.Male][PreGameLib.CodeEnumFaction.Dominion] = 7736
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Granok][PreGameLib.CodeEnumGender.Female] = {}
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Granok][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Exile] = 7737
c_cameraZoomAnimation[PreGameLib.CodeEnumRace.Granok][PreGameLib.CodeEnumGender.Female][PreGameLib.CodeEnumFaction.Dominion] = 7737

function Character:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Character:Init()
	Apollo.RegisterAddon(self)
end

function Character:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Character.xml")

	self.bHaveCharacters = false

	math.randomseed(PreGameLib.GetTimeBasedSeed())

	Apollo.RegisterEventHandler("AnimationFinished", "OnAnimationFinished", self)

	Apollo.RegisterEventHandler("QueueStatus", "OnQueueStatus", self)
	Apollo.RegisterEventHandler("CharacterList", "OnCharacterList", self)
	Apollo.RegisterEventHandler("OpenCharacterCreateBtn", "OnOpenCharacterCreate", self)
	Apollo.RegisterEventHandler("Select_SetModel", "OnConfigureModel", self)
	Apollo.RegisterEventHandler("CharacterCreateFailed", "OnCreateCharacterFailed", self)
	Apollo.RegisterEventHandler("RealmBroadcast", "OnRealmBroadcast", self)

	Apollo.RegisterTimerHandler("InitialLoadTimer", "OnInitialLoadTimer", self)
	Apollo.RegisterTimerHandler("CreateFailedTimer", "OnCreateFailedTimer", self)
	Apollo.RegisterTimerHandler("RealmBroadcastTimer", "OnRealmBroadcastTimer", self)

	Apollo.CreateTimer("RealmBroadcastTimer", 10.0, false)
	Apollo.StopTimer("RealmBroadcastTimer")

	--These refer to the global controls that live in this file
	g_controls = Apollo.LoadForm(self.xmlDoc, "PregameControls", "Navigation", self)
	g_controls:Show(false)

	g_controlCatcher = Apollo.LoadForm(self.xmlDoc, "PregameMouseCatcher", "TempBlocker", self)

	g_nState = LuaEnumState.Select
	g_arCharacters = {}
	g_arCharacterInWorld = {}

	-- This is the 3d scene used for both CC and CS
	g_scene = PreGameLib.uScene
	g_scene:SetMap( 1559 );
	g_scene:SetCameraFoVNearFar( 50, .1, 512 ) -- field of view, near plane and far plane settings for camera.  Can not set near plane to 0.  Setting a very small near plane causes graphic artifacts.
	g_scene:SetMapTimeOfDay(c_SceneTime) -- in seconds from midnight. New band now playing!

	g_tPositionOffset = Vector3:Zero() -- Vector3.New(-5412.58, -988.033, -6383.37)

	-- set the camera position so we dont try to load blank space first.
	local lookAt = Vector3.New(1,0,0)
	local up = Vector3.New(0,1,0)

	g_arActors = {} -- our models

	self.tCameraOffset = Vector3:Zero() --Vector3.New(-5412.82, -989, -6383.48)
	g_arActors.mainScene = g_scene:AddActorByFile( 10000, "Art\\Prop\\Character_Creation\\MainScene\\CharacterCreation_MainScene.m3" )
	if g_arActors.mainScene then
		g_arActors.mainScene:SetPosition(1, self.tCameraOffset, Vector3:Zero())
		g_arActors.mainScene:AttachCamera(7) -- Cinematic_01
	end

	g_arActors.characterAttach = g_scene:AddActorByFile( 10001, "Art\\Prop\\Character_Creation\\MainScene\\CharacterCreation_MainScene_CharacterRotation.m3")
	if g_arActors.characterAttach then
		g_arActors.characterAttach:SetPosition(1, self.tCameraOffset, Vector3:Zero())
	end

	g_arActors.factionIcon = g_scene:AddActorByFile( 10010, "Art\\Prop\\Character_Creation\\Icons\\PRP_CharacterCreation_ATT_Faction_000.m3" )
	if g_arActors.factionIcon then
		g_arActors.factionIcon:AttachToActor( g_arActors.mainScene, 74 )
	end

	g_arActors.pathIcon = g_scene:AddActorByFile( 10011, "Art\\Prop\\Character_Creation\\Icons\\PRP_CharacterCreation_ATT_Path_000.m3" )
	if g_arActors.pathIcon then
		g_arActors.pathIcon:AttachToActor( g_arActors.mainScene, 18 )
	end
	g_arActors.weaponIcon = g_scene:AddActorByFile( 10012, "Art\\Prop\\Character_Creation\\Icons\\PRP_CharacterCreation_ATT_Weapon_000.m3" )

	if g_arActors.weaponIcon then
		g_arActors.weaponIcon:AttachToActor( g_arActors.mainScene, 75 )
	end

	-- hide them all
	if g_arActors.factionIcon ~= nil then
		g_arActors.factionIcon:Animate(0, 6670, 0, true, false)
	end

	if g_arActors.weaponIcon ~= nil then
		g_arActors.weaponIcon:Animate(0, 6667, 0, true, false)
	end

	if g_arActors.pathIcon ~= nil then
		g_arActors.pathIcon:Animate(0, 1109, 0, true, false)
	end
	----

	g_arActors.warningLight1 = g_scene:AddActorByFile( 10013, "Art\\Prop\\Constructed\\Light\\Marauder\\PRP_AlarmLight_RMC_Red_000.m3" )
	if g_arActors.warningLight1 then
		g_arActors.warningLight1:AttachToActor( g_arActors.mainScene, 76 )
	end

	g_arActors.warningLight2 = g_scene:AddActorByFile( 10014, "Art\\Prop\\Constructed\\Light\\Marauder\\PRP_AlarmLight_RMC_Red_000.m3" )
	if g_arActors.warningLight2 then
		g_arActors.warningLight2:AttachToActor( g_arActors.mainScene, 77 )
	end

	g_cameraAnimation = 150
	g_cameraSlider = 0

	self.wndCharacterListPrompt = Apollo.LoadForm(self.xmlDoc, "CharacterListPrompt", nil, self)
	self.wndCharacterListPrompt:Show(true)

	self.wndRealmName = Apollo.LoadForm(self.xmlDoc, "RealmNameForm", nil, self)
	self.wndInfoPane = Apollo.LoadForm(self.xmlDoc, "InfoPane_Overall", nil, self)

	self.wndCreateFrame = Apollo.LoadForm(self.xmlDoc, "CharacterCreationControls", nil, self)
	self.wndCreateFrame:Show(false)
	self.wndRacePicker = self.wndCreateFrame:FindChild("RaceSelectFrame")
	self.wndClassPicker = self.wndCreateFrame:FindChild("ClassSelectFrame")
	self.wndPathPicker = self.wndCreateFrame:FindChild("PathSelectFrame")
	self.wndControlFrame = self.wndCreateFrame:FindChild("LeftControlFrame")
	self.wndControlFrame:FindChild("GlowAssets"):Show(false)

	self.wndControlFrame:FindChild("RaceOptionToggle"):AttachWindow(self.wndRacePicker)
	self.wndControlFrame:FindChild("ClassOptionToggle"):AttachWindow(self.wndClassPicker)
	self.wndControlFrame:FindChild("PathOptionToggle"):AttachWindow(self.wndPathPicker)

	self.wndName = g_controls:FindChild("NameEntryForm")
	self.wndNameEntry = self.wndName:FindChild("EnterNameEntry")

	self.wndCreateCode = g_controls:FindChild("CodeEntryForm")
	self.wndCreateCodeEntry = self.wndCreateCode:FindChild("CreateCodeEditBox")
	self.wndCreateCode:Show(false)

	self.wndCustOptionPanel = Apollo.LoadForm(self.xmlDoc, "CustomizeOptionPane", nil, self)
	self.wndCustPaginationList = self.wndCustOptionPanel:FindChild("CustomizeControlFrame")
	self.wndCustOptionList = self.wndCustOptionPanel:FindChild("CustomizeOptionPicker")
	self.wndCustOptionUndoBtn = self.wndCustOptionList:FindChild("ResetPickerOptionBtn")
	self.iCurrentPage = 0 -- used for paging through customize features
	self.wndCustAdvanced = self.wndCustOptionPanel:FindChild("AdvancedEditingWindow")
	self.wndCustAdvanced:Show(false)

	self.wndCreateFailed = Apollo.LoadForm(self.xmlDoc, "CreateErrorMessage", nil, self)
	self.wndCreateFailed:Show(false)

	self.wndRealmFull = Apollo.LoadForm(self.xmlDoc, "CapacityQueueForm", nil, self)
	self.wndRealmFull:Show(false)

	self.arServerMessages = PreGameLib.GetLastRealmMessages()
	self.wndServerMessagesContainer = Apollo.LoadForm(self.xmlDoc, "RealmMessagesContainer", nil, self)
	self.wndServerMessage = self.wndServerMessagesContainer:FindChild("RealmMessage")
	self:HelperServerMessages()


	self.wndRealmBroadcast = Apollo.LoadForm(self.xmlDoc, "RealmBroadcastMessage", nil, self)
	self.wndRealmBroadcast:Show(false)

	-- Character Creation objects
	self.arCustomizeLookOptions = {}
	self.arCustomizeBoneOptions = {}
	self.arCustomizeBoneOptionsPrev = {}
	self.arWndCustomizeBoneOptions = {}
	self.arCustomizeOptionBtns = {}
	self.arPreviousCharacterOptions = {}
	self.arCustomizePaginationBtns = {}
	self.arPreviousSliderOptions = {}
	g_nCharCurrentRot = 0

	self.iSelectedPath = math.random(0, 3)
	self.arClasses2 = {}
	self.arRaces2 = {}
	self.arCharacterCreateOptions = CharacterScreenLib.GetCharacterCreation() -- needs to be before set visible forms.
	self.iPreviousOption = nil -- used for setting undo's on customize

	self:FillPickerButtons()
	self:HideCharacterCreate()

	self.nCreationTable = 0 -- used to identify enabled characters
	self.iPreviousOption = nil

	Apollo.CreateTimer("InitialLoadTimer", 1, false)
end

function Character:OnAnimationFinished(actor, slot, modelSequence)
	-- do something if you want to know when an animation finished
end

	---------------------------------------------------------------------------------------------------
-- Entry Events
---------------------------------------------------------------------------------------------------
-- Receiving this event means the player has been queued due to capacity; direct to that screen
function Character:OnQueueStatus( nPositionInQueue, nEstimatedWaitInSeconds, bIsGuest )
	local tRealmInfo = CharacterScreenLib.GetRealmInfo()
	local strRealmType = tRealmInfo.nRealmPVPType == PreGameLib.CodeEnumRealmPVPType.PVP and Apollo.GetString("RealmSelect_PvP") or Apollo.GetString("RealmSelect_PvE")
	self.wndRealmFull:Show(true)
	self.wndRealmFull:FindChild("CapacityFormCenter"):FindChild("GuestOnlyMessage"):Show(bIsGuest)
	self.wndRealmFull:FindChild("CapacityFormCenter"):FindChild("Title"):SetText(Apollo.GetString("Pregame_RealmFull"))
	self.wndRealmFull:FindChild("CapacityFormCenter"):FindChild("Body"):SetText(kstrRealmFullClosed)
	self.wndRealmFull:FindChild("PositionInfoBacker"):Show(true)
	self.wndRealmFull:FindChild("PositionInQueueEntry"):SetText(Apollo.GetString("Pregame_RealmQueue_Position") .. " " .. tostring(nPositionInQueue))
	self.wndRealmFull:FindChild("WaitTimeEntry"):SetText(Apollo.GetString("MatchMaker_WaitTimeLabel").. " " .. self:HelperConvertToTime(nEstimatedWaitInSeconds or 0))
	self.wndRealmFull:FindChild("QueuedRealm"):SetText(Apollo.GetString("Pregame_RealmQueue_RealmName").. " " .. tostring(tRealmInfo.strName).." (".. strRealmType ..")")

	self.wndCharacterListPrompt:Show(false)
end
-- Receiving this event means the player's character list has come down. Note: can happen when on the queue screen.
function Character:OnCharacterList( arCharacters, arCharacterInWorld )
	if self.wndRealmFull:IsShown() then
		Apollo.StopTimer("InitialLoadTimer")
		self.wndRealmFull:Show(false)
		self.wndRealmFull:FindChild("WaitTimeEntry"):SetText("")
		self.wndRealmFull:FindChild("PositionInQueueEntry"):SetText("")
		self.wndRealmFull:FindChild("PositionInfoBacker"):Show(false)
		self.wndRealmFull:FindChild("CapacityFormCenter"):FindChild("Title"):SetText(Apollo.GetString("Pregame_RealmAvailable"))
		self.wndRealmFull:FindChild("CapacityFormCenter"):FindChild("Body"):SetText(kstrRealmFullOpen)
		g_arCharacters = arCharacters
		g_arCharacterInWorld = arCharacterInWorld

		Sound.Play(Sound.PlayUIQueuePopsAdventure)
		self:OpenCharacterSelect()
		return
	end

	g_arCharacters = arCharacters
	g_arCharacterInWorld = arCharacterInWorld
	self.bHaveCharacters = true
end

function Character:OnInitialLoadTimer()
	if self.bHaveCharacters == false then
		Apollo.CreateTimer("InitialLoadTimer", 1, false)
		return
	end
	self:OpenCharacterSelect()
end

function Character:OnChangeRealmBtn(wndHandler, wndControl)
	self.wndRealmFull:Show(false)
	CharacterScreenLib.ExitToRealmSelect()
end

function Character:OnLeaveQueueBtn(wndHandler, wndControl)
	CharacterScreenLib.ExitToLogin()
end

---------------------------------------------------------------------------------------------------
-- State Machine
---------------------------------------------------------------------------------------------------
function Character:OpenCharacterSelect()
	self.wndCharacterListPrompt:Show(false)
	self:HideCharacterCreate()
	self.wndServerMessagesContainer:Show(true)
	g_controls:Show(true)
	self.wndName:Show(false)
	self.wndNameEntry:SetText("")
	self.wndCreateCode:Show(false)
	self.wndName:FindChild("CheckMarkIcon"):SetSprite("")
	g_controls:FindChild("EnterForm"):Show(true)

	g_nState = LuaEnumState.Select
	g_controlCatcher:SetFocus()

	PreGameLib.Event_FireGenericEvent("LoadFromCharacter")
	PreGameLib.SetMusic(PreGameLib.CodeEnumMusic.CharacterSelect)

	g_cameraSlider = 0
	g_arActors.mainScene:Animate(0, g_cameraAnimation, 0, true, false, 0, g_cameraSlider)
end

function Character:OnOpenCharacterCreate()
	g_controls:Show(false)
	self.wndServerMessagesContainer:Show(false)
	self.characterCreateIndex = 0
	self:EnableButtons()

	self:SetInitialCreateForms()
	PreGameLib.SetMusic(PreGameLib.CodeEnumMusic.CharacterCreate)

	g_cameraSlider = 0
	g_arActors.mainScene:Animate(0, g_cameraAnimation, 0, true, false, 0, g_cameraSlider)
end


function Character:OnEnterBtn(wndHandler, wndControl)
	if g_nState == LuaEnumState.Create then
		self.strName = self.wndNameEntry:GetText()
		if string.len(self.strName) > 0 and self.arCharacterCreateOptions[self.characterCreateIndex] then
			CharacterScreenLib.CreateCharacter(self.strName, self.arCharacterCreateOptions[self.characterCreateIndex].characterCreateId, g_arActors.primary, self.iSelectedPath)
		end
	elseif g_nState == LuaEnumState.Select and wndControl:GetData() ~= nil then
		PreGameLib.Event_FireGenericEvent("SelectCharacter", wndControl:GetData())
	else
		return -- unhandled; should never occur
	end
end

function Character:OnBackBtn(wndHandler, wndControl)
	if g_nState == LuaEnumState.Create then
		self:OpenCharacterSelect()
		PreGameLib.Event_FireGenericEvent("Pregame_CreationToSelection")
	elseif g_nState == LuaEnumState.Select then
		CharacterScreenLib.ExitToLogin()
	elseif g_nState == LuaEnumState.Delete then
		self:OpenCharacterSelect()
		PreGameLib.Event_FireGenericEvent("Pregame_CreationToSelection")
	elseif g_nState == LuaEnumState.Customize then
		self:OnAcceptCustomizeBtn()
	else
		return -- unhandled; should never occur
	end
end


---------------------------------------------------------------------------------------------------
-- Visiblity Settings
---------------------------------------------------------------------------------------------------
function Character:HideCharacterCreate()

	g_controls:Show(false)

	self.wndCreateFrame:Show(false)
	self.wndRacePicker:Show(false)
	self.wndClassPicker:Show(false)
	self.wndPathPicker:Show(false)
	self.wndControlFrame:FindChild("GlowAssets"):Show(false)

	self.wndName:Show(false)
	self.wndNameEntry:SetText("")
	self.wndName:FindChild("CheckMarkIcon"):SetSprite("")


	self.wndInfoPane:Show(false)
	self.wndCustOptionPanel:Show(false)
end

function Character:SetInitialCreateForms()
	-- TODO: Skip this once a faction has been selected on a realm

	g_controls:Show(false)
	g_nState = LuaEnumState.Create
	g_controls:FindChild("EnterBtn"):Enable(false)
	g_controls:FindChild("EnterForm"):FindChild("EnterLabel"):SetTextColor(ApolloColor.new("ff3c524f"))

	g_controls:FindChild("EnterForm"):FindChild("BGArt_BottomRunnerName"):Show(true)
	g_controls:FindChild("EnterForm"):FindChild("BGArt_BottomRunner"):Show(false)

	self.iSelectedPath = math.random(0, 3)

	self.wndCreateFrame:FindChild("ExileBtn"):SetCheck(false)
	self.wndCreateFrame:FindChild("DominionBtn"):SetCheck(false)

	g_controls:FindChild("CameraControls"):Show(false)

	self.wndCreateFrame:Show(false)
	self.wndRacePicker:Show(false)
	self.wndClassPicker:Show(false)
	self.wndPathPicker:Show(false)
	self.wndControlFrame:FindChild("GlowAssets"):Show(false)

	self.wndInfoPane:Show(false)
	self.wndCustOptionPanel:Show(false)
	self.wndNameEntry:SetText("")

	self:SetOptionsFaction()
end


function Character:SetOptionsFaction()

	local tExiles = CharacterScreenLib.GetCharacterCreationIdsByValues(0, PreGameLib.CodeEnumFaction.Exile, -1, -1, -1)
	local bExile = #tExiles.arEnabledIds > 0

	local tDominion = CharacterScreenLib.GetCharacterCreationIdsByValues(0, PreGameLib.CodeEnumFaction.Dominion, -1, -1, -1)
	local bDominion = #tDominion.arEnabledIds > 0

	self.wndCreateFrame:FindChild("ExileBtn"):Enable(bExile)
	self.wndCreateFrame:FindChild("DominionBtn"):Enable(bDominion)

	if bExile == true and bDominion == false then
		self:OnSelectDefiance()
		self.wndCreateFrame:FindChild("ExileBtn"):SetCheck(true)
	elseif bExile == false and bDominion == true then
		self:OnSelectDominion()
		self.wndCreateFrame:FindChild("DominionBtn"):SetCheck(true)
	elseif bExile == true and bDominion == true then
		local nRandom = math.random(1,2)
		if nRandom == 1 then
			self:OnSelectDefiance()
			self.wndCreateFrame:FindChild("ExileBtn"):SetCheck(true)
		else
			self:OnSelectDominion()
			self.wndCreateFrame:FindChild("DominionBtn"):SetCheck(true)
		end
	end

	self:SetCreateForms()
end


function Character:SetCreateForms()

	g_nState = LuaEnumState.Create
	g_controlCatcher:SetFocus()

	self.wndCreateFrame:Show(true)
	self.wndRacePicker:Show(false)
	self.wndClassPicker:Show(false)
	self.wndPathPicker:Show(false)
	self.wndCustOptionList:Show(false)
	self.wndCustAdvanced:Show(false)
	self.wndName:Show(true)
	self.wndControlFrame:FindChild("GlowAssets"):Show(false)

	g_controls:Show(true)
	g_controls:FindChild("EnterForm"):Show(true)
	g_controls:FindChild("EnterForm"):FindChild("EnterLabel"):SetText(Apollo.GetString("Pregame_Create"))
	g_controls:FindChild("ExitForm"):Show(true)
	g_controls:FindChild("ExitForm"):FindChild("BackBtnLabel"):SetText(Apollo.GetString("CRB_Cancel"))
	g_controls:FindChild("OptionsContainer"):Show(true)

	self.wndInfoPane:Show(true)
	self.wndCustOptionPanel:Show(false)

	--Display realm information
	local tRealmInfo = CharacterScreenLib.GetRealmInfo()
	local tRealm = {}
	local strRealm = ""
	local strRealmName = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBodyHighlight\">%s</T>", tostring(tRealmInfo.strName))
	local strRealmLabel = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloTitle\">%s</T>", Apollo.GetString("CharacterSelect_RealmLabel"))
	local strRealmType = tRealmInfo.nRealmPVPType == PreGameLib.CodeEnumRealmPVPType.PVP and Apollo.GetString("RealmSelect_PvP") or Apollo.GetString("RealmSelect_PvE")
	strRealmType = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBodyHighlight\">%s</T>", "("..strRealmType..")")
	strRealm = string.format("<P Align=\"Center\">%s %s</P>", strRealmLabel .. "    " .. strRealmName, strRealmType)
	self.wndCreateFrame:FindChild("RealmLabel"):SetText(strRealm)
	self.wndCreateFrame:FindChild("RealmNote"):SetText(tRealmInfo.strRealmNote)
	self.wndCreateFrame:FindChild("RealmNote"):Show(string.len(tRealmInfo.strRealmNote or "") > 0)
end

function Character:SetVisibleCustomizeForms()
	self.wndCreateFrame:Show(false)
	self.wndRacePicker:Show(false)
	self.wndClassPicker:Show(false)
	self.wndPathPicker:Show(false)
	self.wndControlFrame:FindChild("GlowAssets"):Show(false)

	self.wndControlFrame:FindChild("RaceOptionToggle"):FindChild("AnimOverlay"):Show(false)
	self.wndControlFrame:FindChild("ClassOptionToggle"):FindChild("AnimOverlay"):Show(false)
	self.wndControlFrame:FindChild("PathOptionToggle"):FindChild("AnimOverlay"):Show(false)

	g_nState = LuaEnumState.Customize

	g_controls:Show(true)
	g_controls:FindChild("EnterForm"):Show(false)
	g_controls:FindChild("ExitForm"):Show(false)
	g_controls:FindChild("ExitForm"):FindChild("BackBtnLabel"):SetText(Apollo.GetString("CRB_Cancel"))
	g_controls:FindChild("OptionsContainer"):Show(true)
	self.wndName:Show(false)

	self.wndInfoPane:Show(false)
	self.wndCustOptionPanel:Show(true)
end

---------------------------------------------------------------------------------------------------
-- Character Faction Select
---------------------------------------------------------------------------------------------------
function Character:OnSelectDefiance()
	if s_isInSelectButtons then
		return
	end

	local tSelectedOptions = self:GetSelectedOptionsCopy()

	--lets always do a random race and gender of the correct class
	local possibleCharacterCreateIndex = self:GetCharacterCreateId(PreGameLib.CodeEnumFaction.Exile, nil, tSelectedOptions.classId, nil)

	-- dont change if we dont find it
	if possibleCharacterCreateIndex ~= 0 then
		self:SetCharacterCreateIndex( possibleCharacterCreateIndex )
	end

	local strFaction = self.wndRealmName:GetText()
	strFaction = PreGameLib.String_GetWeaselString(Apollo.GetString("Pregame_FactionListing"), strFaction, string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceLarge_B", "ff32fcf6", "(" .. Apollo.GetString("CRB_Exiles") .. ")"))

	self:SelectButtons()
	self:EnableButtons()

	self:OnRandomizeBtn()
end

---------------------------------------------------------------------------------------------------
function Character:OnSelectDominion()
	if s_isInSelectButtons then
		return
	end

	local tSelectedOptions = self:GetSelectedOptionsCopy()

	--lets always do a random race and gender of the correct class
	local possibleCharacterCreateIndex = self:GetCharacterCreateId(PreGameLib.CodeEnumFaction.Dominion, nil, tSelectedOptions.classId, nil)

	-- dont change if we dont find it
	if possibleCharacterCreateIndex ~= 0 then
		self:SetCharacterCreateIndex( possibleCharacterCreateIndex )
	end

	local strFaction = self.wndRealmName:GetText()
	strFaction = PreGameLib.String_GetWeaselString(Apollo.GetString("Pregame_FactionListing"), strFaction, string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceLarge_B", "ff32fcf6", "(" .. Apollo.GetString("CRB_Exiles") .. ")"))

	self:SelectButtons()
	self:EnableButtons()

	self:OnRandomizeBtn()
end

---------------------------------------------------------------------------------------------------
-- Character Race/Class/Gender/Path Select
---------------------------------------------------------------------------------------------------
function Character:FillPickerButtons()
	local classIdx = 1
	local raceIdx = 1
	local selected = self.arCharacterCreateOptions[self.characterCreateIndex]

	self.wndRacePicker:FindChild("Content"):DestroyChildren()

	for idx, creation in pairs(self.arCharacterCreateOptions) do
		if self.arClasses2[creation.classId] == nil and c_arAllowedClass[creation.classId] and classIdx <= 9 then
			self.arClasses2[creation.classId] = { wnd = self.wndClassPicker:FindChild("ClassBtn"..classIdx), btnIdx = classIdx }
			self.arClasses2[creation.classId].wnd:SetData(creation.classId)
			classIdx = classIdx + 1
		end

		if self.arRaces2[creation.raceId] == nil and c_arAllowedRace[creation.raceId] and raceIdx <= 7 then
			local wndRace = Apollo.LoadForm(self.xmlDoc, "RaceGenderPickerEntry", self.wndRacePicker:FindChild("Content"), self)

			self.arRaces2[creation.raceId] = { wnd = wndRace, btnIdx = raceIdx }
			self.arRaces2[creation.raceId].wnd:FindChild("TitleEntry"):SetText(Apollo.GetString(c_arRaceStrings[creation.raceId][1]))
			self.arRaces2[creation.raceId].wnd:FindChild("HorizontalSortContainer"):FindChild("RaceOptionMale"):SetData(creation.raceId)
			self.arRaces2[creation.raceId].wnd:FindChild("HorizontalSortContainer"):FindChild("RaceOptionFemale"):SetData(creation.raceId)
			self.arRaces2[creation.raceId].wnd:SetData(creation.raceId)

			if creation.raceId == 13 then
				self.arRaces2[creation.raceId].wnd:FindChild("HorizontalSortContainer"):FindChild("RaceOptionFemale"):Show(false)
				self.arRaces2[creation.raceId].wnd:FindChild("HorizontalSortContainer"):FindChild("RaceOptionMale"):ChangeArt(c_arRaceButtons[creation.raceId].male)
			else
				self.arRaces2[creation.raceId].wnd:FindChild("HorizontalSortContainer"):FindChild("RaceOptionMale"):ChangeArt(c_arRaceButtons[creation.raceId].male)
				self.arRaces2[creation.raceId].wnd:FindChild("HorizontalSortContainer"):FindChild("RaceOptionFemale"):ChangeArt(c_arRaceButtons[creation.raceId].female)
			end

			self.arRaces2[creation.raceId].wnd:FindChild("HorizontalSortContainer"):ArrangeChildrenHorz(1)
			raceIdx = raceIdx + 1
		end
	end

	self.wndRacePicker:FindChild("Content"):ArrangeChildrenVert()

	----------------------------------------------

	local arPaths = CharacterScreenLib.GetPlayerPaths()
	for i = 1,#arPaths do
		self.wndPathPicker:FindChild("PathBtn" .. i):SetData(arPaths[i].path)
	end
end




---------------------------------------------------------------------------------------------------
function Character:EnableButtons()

	local selected = self.arCharacterCreateOptions[self.characterCreateIndex]


	if selected == nil then
		for raceIdx, races in pairs(self.arRaces2) do
			races.wnd:Enable(true)
		end


		for classIdx, classes in pairs(self.arClasses2) do
			classes.wnd:Enable(true)
		end
		return
	end

	local enabledRaces = {}
	local enabledClasses = {}
	local enabledGenders = {}


	for idx, creation in pairs(self.arCharacterCreateOptions) do
		if selected.factionId == creation.factionId then   -- only care about faction.  Class will auto change it if needed
			if creation.enabled == 1 or Apollo.GetConsoleVariable("ui.enableDevCreate") == true then
				enabledRaces[creation.raceId] = true

			end
		end
	end

	for raceIdx, races in pairs(self.arRaces2) do
		races.wnd:Show(enabledRaces[raceIdx] ~= nil)

		--demoIndex, factionId, classId, raceId, genderId
		local tMale = CharacterScreenLib.GetCharacterCreationIdsByValues(0, selected.factionId, -1, raceIdx, PreGameLib.CodeEnumGender.Male)
		races.wnd:FindChild("RaceOptionMale"):Enable(#tMale.arEnabledIds > 0)

		local tFemale = CharacterScreenLib.GetCharacterCreationIdsByValues(0, selected.factionId, -1, raceIdx, PreGameLib.CodeEnumGender.Female)
		races.wnd:FindChild("RaceOptionFemale"):Enable(#tFemale.arEnabledIds > 0)

	end

	-- Enable all races/classes that are selectable from current race/class pick
	for idx, creation in pairs(self.arCharacterCreateOptions) do
		if selected.raceId == creation.raceId and selected.factionId == creation.factionId and selected.genderId == creation.genderId then
			if creation.enabled == 1 or Apollo.GetConsoleVariable("ui.enableDevCreate") == true then
				enabledClasses[creation.classId] = true
			end
		end
	end

	self.wndRacePicker:FindChild("Content"):ArrangeChildrenVert()

	for classIdx, classes in pairs(self.arClasses2) do
		classes.wnd:Enable(enabledClasses[classIdx] ~= nil)

		if classes.wnd:IsEnabled() then
			classes.wnd:FindChild("Icon"):SetBGColor(CColor.new(1, 1, 1, 1))
			classes.wnd:SetBGColor(CColor.new(1, 1, 1, 1))
			if selected.classId == 7 then -- custom handling for the Spellslinger
				classes.wnd:SetCheck(classes.btnIdx == 6)
			else
				classes.wnd:SetCheck(classes.btnIdx == selected.classId)
			end

			classes.wnd:SetText("           " .. Apollo.GetString(c_arClassStrings[classIdx][1]))
			classes.wnd:FindChild("IconFrame"):SetSprite("CRB_CharacterCreateSprites:sprCharC_ClassFooterIconBlue")

			self.wndRacePicker:FindChild("ClassIconBlocker" .. classIdx):Show(false)

		else
			classes.wnd:SetText("           " .. Apollo.GetString(c_arClassStrings[classIdx][1]))
			classes.wnd:FindChild("Icon"):SetBGColor(CColor.new(1, 1, 1, .2))
			classes.wnd:SetBGColor(CColor.new(.6, .6, .6, .6))
			classes.wnd:FindChild("IconFrame"):SetSprite("CRB_CharacterCreateSprites:sprCharC_ClassFooterIconDisabled")

			self.wndRacePicker:FindChild("ClassIconBlocker" .. classIdx):Show(true)
		end

		if classes.wnd:IsChecked() then
			classes.wnd:FindChild("IconFrame"):SetSprite("CRB_CharacterCreateSprites:sprCharC_ClassFooterIconWhite")
		end
	end

	self.strName = self.wndNameEntry:GetText()
end

---------------------------------------------------------------------------------------------------
function Character:SelectButtons()
	local selected = self.arCharacterCreateOptions[self.characterCreateIndex]

	if selected == nil then
		return
	end
	s_isInSelectButtons = true

	if selected.factionId == PreGameLib.CodeEnumFaction.Dominion then -- Dominion
		self.arRaces2[1].wnd:FindChild("TitleEntry"):SetText(Apollo.GetString(c_arRaceStrings[100][1]))
		self.arRaces2[1].wnd:FindChild("HorizontalSortContainer"):FindChild("RaceOptionMale"):ChangeArt(c_arRaceButtons[100].male)
		self.arRaces2[1].wnd:FindChild("HorizontalSortContainer"):FindChild("RaceOptionFemale"):ChangeArt(c_arRaceButtons[100].female)
	else
		self.arRaces2[1].wnd:FindChild("TitleEntry"):SetText(Apollo.GetString(c_arRaceStrings[1][1]))
		self.arRaces2[1].wnd:FindChild("HorizontalSortContainer"):FindChild("RaceOptionMale"):ChangeArt(c_arRaceButtons[1].male)
		self.arRaces2[1].wnd:FindChild("HorizontalSortContainer"):FindChild("RaceOptionFemale"):ChangeArt(c_arRaceButtons[1].female)
	end

	self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField1"):SetText(Apollo.GetString(c_arFactionStrings[selected.factionId]))
	self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField1"):SetHeightToContentHeight()

	for idx, race in pairs(self.arRaces2) do
		race.wnd:FindChild("RaceOptionMale"):SetCheck(false)
		race.wnd:FindChild("RaceOptionFemale"):SetCheck(false)
	end

	-- Set race buttons and info
	if self.arRaces2[selected.raceId] ~= nil then  -- race
		if selected.genderId == PreGameLib.CodeEnumGender.Male then
			self.wndRacePicker:SetRadioSelButton("CharacterCreate_RaceSelection", self.arRaces2[selected.raceId].wnd:FindChild("RaceOptionMale"))
			self.arRaces2[selected.raceId].wnd:FindChild("RaceOptionMale"):SetCheck(true) -- shouldn't be needed, guarantees the check is shown
		elseif selected.genderId == PreGameLib.CodeEnumGender.Female then
			self.wndRacePicker:SetRadioSelButton("CharacterCreate_RaceSelection", self.arRaces2[selected.raceId].wnd:FindChild("RaceOptionFemale"))
			self.arRaces2[selected.raceId].wnd:FindChild("RaceOptionFemale"):SetCheck(true) -- shouldn't be needed, guarantees the check is shown
		end

		if selected.raceId == 1 then --humans
			if selected.factionId == PreGameLib.CodeEnumFaction.Dominion then -- Dominion
				self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField2"):SetText(Apollo.GetString(c_arRaceStrings[100][2]))
				self.wndControlFrame:FindChild("RaceOptionToggle"):FindChild("RaceSelection"):SetText(Apollo.GetString(c_arRaceStrings[100][1]))
			else
				self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField2"):SetText(Apollo.GetString(c_arRaceStrings[selected.raceId][2]))
				self.wndControlFrame:FindChild("RaceOptionToggle"):FindChild("RaceSelection"):SetText(Apollo.GetString(c_arRaceStrings[selected.raceId][1]))
			end
		else
			self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField2"):SetText(Apollo.GetString(c_arRaceStrings[selected.raceId][2]))
			self.wndControlFrame:FindChild("RaceOptionToggle"):FindChild("RaceSelection"):SetText(Apollo.GetString(c_arRaceStrings[selected.raceId][1]))
		end

		self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField2"):SetHeightToContentHeight()
	end

	if self.arClasses2[selected.classId] ~= nil then -- classes; this has to update for demo auto-selection...
		self.wndClassPicker:SetRadioSelButton("ClassSelect", self.arClasses2[selected.classId].wnd)
		self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField3"):SetText(Apollo.GetString(c_arClassStrings[selected.classId][2]))
		self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField3"):SetHeightToContentHeight()
		self.wndControlFrame:FindChild("ClassOptionToggle"):FindChild("ClassSelection"):SetText(Apollo.GetString(c_arClassStrings[selected.classId][1]))
	end

	for i = 1,4 do
		if self.wndPathPicker:FindChild("PathBtn" .. i) ~= nil then
			self.wndPathPicker:FindChild("PathBtn" .. i):SetCheck((self.iSelectedPath ~= nil) and ((i-1) == self.iSelectedPath))
		end
	end

	if self.iSelectedPath ~= nil then
		self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField4"):SetText(Apollo.GetString(c_arPathStrings[self.iSelectedPath][2]))
		self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField4"):SetHeightToContentHeight()
		self.wndControlFrame:FindChild("PathOptionToggle"):FindChild("PathSelection"):SetText(Apollo.GetString(c_arPathStrings[self.iSelectedPath][1]))
	else
		self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField4"):SetText(Apollo.GetString("CRB_CC_Path_SelectPathPrompt"))
		self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField4"):SetHeightToContentHeight()
	end

	self:FormatInfoPanel()

	s_isInSelectButtons = false
end

function Character:FormatInfoPanel()
	local nContentHeight = 0
	for idx = 1, 4 do
		local nTitleHeight = self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("TitleField" .. idx):GetHeight()
		local nBodyHeight = self.wndInfoPane:FindChild("InfoPane_SortContainer"):FindChild("InfoField" .. idx):GetHeight()
		nContentHeight = nContentHeight + nTitleHeight + nBodyHeight
	end


	self.wndInfoPane:FindChild("InfoPane_SortContainer"):ArrangeChildrenVert()

	local l, t, r, b = self.wndInfoPane:FindChild("InfoPane_SortContainer"):GetAnchorOffsets()
	local lFrame, tFrame, rFrame, bFrame = self.wndInfoPane:GetAnchorOffsets()
	local nTotalHeight = nContentHeight-b+t
	self.wndInfoPane:SetAnchorOffsets(lFrame, -(nTotalHeight/2), rFrame, nTotalHeight/2)
end

---------------------------------------------------------------------------------------------------
function Character:SetCharacterCreateIndex( characterCreateIndex )

	--Set the main and shadow character. The shadow is used to populate our option lists during customization and is discretely placed waaaaaaaay off into space.
	if g_arActors.primary == nil or g_bReplaceActor == true or self.characterCreateIndex == nil or self.arCharacterCreateOptions[self.characterCreateIndex] == nil or
	self.arCharacterCreateOptions[self.characterCreateIndex].raceId ~= self.arCharacterCreateOptions[characterCreateIndex].raceId or
	self.arCharacterCreateOptions[self.characterCreateIndex].factionId ~= self.arCharacterCreateOptions[characterCreateIndex].factionId or
	   self.arCharacterCreateOptions[self.characterCreateIndex].genderId ~= self.arCharacterCreateOptions[characterCreateIndex].genderId then

		g_arActors.primary = g_scene:AddActorByRaceGender(1, self.arCharacterCreateOptions[characterCreateIndex].raceId, self.arCharacterCreateOptions[characterCreateIndex].genderId)
		if g_arActors.primary then
			g_arActors.primary:SetFaction(self.arCharacterCreateOptions[characterCreateIndex].factionId)
		end
		g_bReplaceActor = false

	end

	g_arActors.shadow = g_scene:AddActorByRaceGender(25, self.arCharacterCreateOptions[characterCreateIndex].raceId, self.arCharacterCreateOptions[characterCreateIndex].genderId)
	if g_arActors.shadow then
		g_arActors.shadow:SetFaction(self.arCharacterCreateOptions[characterCreateIndex].factionId)
		local scaleShadow = 1.0
		local positionShadow = Vector3.New(0, 50, 0) -- set the shadow character waaaaaaaaaaaay off in the stratosphere so he/she doesn't draw
		local rotationShadow = Vector3:Zero()

		g_arActors.shadow:SetPosition( scaleShadow, positionShadow + g_tPositionOffset, rotationShadow )
	end

	if g_arActors.primary then
		g_arActors.primary:SetItemsByCreationId( self.arCharacterCreateOptions[characterCreateIndex].characterCreateId );


		g_nCharCurrentRot = 0
		g_arActors.characterAttach:Animate(0, 1120, 0, true, false, 0, g_nCharCurrentRot)
	end

	if g_arActors.shadow then
		g_arActors.shadow:SetItemsByCreationId( self.arCharacterCreateOptions[characterCreateIndex].characterCreateId );
	end

	self.characterCreateIndex = characterCreateIndex
	self:ConfigureCreateModelSettings()
end

---------------------------------------------------------------------------------------------------
-- Our model settings go here
---------------------------------------------------------------------------------------------------
function Character:ConfigureCreateModelSettings() -- interem step that sets up the model for character create
	local selected = self.arCharacterCreateOptions[self.characterCreateIndex]

	if selected ~= nil then
		self:OnConfigureModel(selected.nRace, selected.nGender, selected.nFaction, selected.nClass, self.iSelectedPath)
	end
end

function Character:OnConfigureModel(nRace, nGender, nFaction, nClass, nPath, nSelectIdx) -- position the model for both create and select
	if g_arActors.primary == nil or g_bReplaceActor == true then return false end

	g_arActors.primary:AttachToActor( g_arActors.characterAttach, 17 )

	g_cameraAnimation = c_cameraZoomAnimation[nRace][nGender][nFaction]
	g_arActors.mainScene:AttachCamera(7)

	if g_arActors.mainScene ~= nil and g_cameraAnimation ~= nil then
		g_arActors.mainScene:Animate(0, g_cameraAnimation, 0, true, false, 0, g_cameraSlider)
	end

	if nSelectIdx ~= nil then -- this will only be true when the call is coming from character select
		CharacterScreenLib.ApplyCharacterToActor( nSelectIdx, g_arActors.primary )
		if c_classSelectAnimation[nClass] ~= nil and g_arActors.primary:IsWeaponEquipped() == true then
			g_arActors.primary:Animate(0, c_classSelectAnimation[nClass], 0, true, false)
		else
			g_arActors.primary:Animate(0, knDefaultReady, 0, true, false)
		end

		if nClass == PreGameLib.CodeEnumClass.Esper then
			g_arActors.primary:SetWeaponSheath(false)
		else
			g_arActors.primary:SetWeaponSheath(true)
		end


		-- Disable the faction/race/class icons
		if g_arActors.factionIcon ~= nil then
			g_arActors.factionIcon:Animate(0, 6670, 0, true, false)
		end

		if g_arActors.weaponIcon ~= nil then
			g_arActors.weaponIcon:Animate(0, 6667, 0, true, false)
		end

		if g_arActors.pathIcon ~= nil then
			g_arActors.pathIcon:Animate(0, 1109, 0, true, false)
		end

	else
		if c_factionPlayerAnimation[nFaction] then
			g_arActors.primary:Animate(0, c_factionPlayerAnimation[nFaction], 0, true, false)
			g_arActors.mainScene:AttachCamera(6) -- should be 6
		end
		g_arActors.primary:SetWeaponSheath(false)

		if g_arActors.factionIcon ~= nil and c_factionIconAnimation[nFaction] ~= nil then
			g_arActors.factionIcon:Animate(0, c_factionIconAnimation[nFaction], 0, true, false)
		end

		if g_arActors.weaponIcon ~= nil and c_classIconAnimation[nClass] ~= nil then
			g_arActors.weaponIcon:Animate(0, c_classIconAnimation[nClass], 0, true, false)
		end

		if g_arActors.pathIcon ~= nil and c_pathIconAnimation[nPath] ~= nil then
			g_arActors.pathIcon:Animate(0, c_pathIconAnimation[nPath], 0, true, false)
		end
	end
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

function Character:OnRaceSelectCheckMale(wndHandler, wndControl)
	if s_isInSelectButtons or wndHandler ~= wndControl then
		return
	end

	if not self.mapCharacterCreateOptions then
		self:BuildOptionsMap()
	end

	local idGender = PreGameLib.CodeEnumGender.Male
	local idRace = wndControl:GetData()

	local tSelectedOptions = self:GetSelectedOptionsCopy()

	local possibleCharacterCreateIndex = self:GetCharacterCreateId(tSelectedOptions.factionId, idRace, tSelectedOptions.classId, idGender)

	-- dont change if we dont find it
	if possibleCharacterCreateIndex ~= 0 then
		self:SetCharacterCreateIndex( possibleCharacterCreateIndex )
	end

	self:SelectButtons() -- run the populate functions
	self:EnableButtons()

	self:OnRandomizeBtn()
end

function Character:OnRaceSelectCheckFemale(wndHandler, wndControl)
	if s_isInSelectButtons or wndHandler ~= wndControl then
		return
	end

	if not self.mapCharacterCreateOptions then
		self:BuildOptionsMap()
	end

	local idGender = PreGameLib.CodeEnumGender.Female
	local idRace = wndControl:GetData()

	local tSelectedOptions = self:GetSelectedOptionsCopy()

	local possibleCharacterCreateIndex = self:GetCharacterCreateId(tSelectedOptions.factionId, idRace, tSelectedOptions.classId, idGender)

	-- dont change if we dont find it
	if possibleCharacterCreateIndex ~= 0 then
		self:SetCharacterCreateIndex( possibleCharacterCreateIndex )
	end

	self:SelectButtons() -- run the populate functions
	self:EnableButtons()

	self:OnRandomizeBtn()
end

---------------------------------------------------------------------------------------------------
function Character:OnClassSelect(wndHandler, wndControl)
	if s_isInSelectButtons or wndHandler ~= wndControl then
		return
	end

	local tSelectedOptions = self:GetSelectedOptionsCopy()
	local idClass = wndControl:GetData()

	local possibleCharacterCreateIndex = self:GetCharacterCreateId(tSelectedOptions.factionId, tSelectedOptions.raceId, idClass, tSelectedOptions.genderId)

	-- dont change if we dont find it
	if possibleCharacterCreateIndex ~= 0 then
		self:SetCharacterCreateIndex( possibleCharacterCreateIndex )
	end

	self:SelectButtons()
	self:EnableButtons()

	if g_arActors.primary then
		self.arCustomizeLookOptions = g_arActors.primary:GetLooks()

		for i, option in pairs(self.arCustomizeLookOptions) do
			g_arActors.shadow:SetLook(option.sliderId, option.values[ option.valueIdx ] )
		end
	end
end

---------------------------------------------------------------------------------------------------
function Character:OnPathSelect(wndHandler, wndControl)
	--self.iSelectedPath = self.wndPathSelectionForm:FindChild("PathBackerArt"):GetRadioSelButton("PathSelect"):GetData()

	if wndHandler ~= wndControl then return false end

	self.iSelectedPath = wndControl:GetData()
	local arPaths = CharacterScreenLib.GetPlayerPaths()
	for i = 1,#arPaths do
		if self.wndPathPicker:FindChild("PathBtn" .. i) ~= nil then
			self.wndPathPicker:FindChild("PathBtn" .. i):SetCheck((i-1) == self.iSelectedPath)
		end
	end

	self:SelectButtons()
	self:EnableButtons()

	local c_pathIconAnimation = {}
	c_pathIconAnimation[PreGameLib.CodeEnumPlayerPathType.Explorer] = 1118
	c_pathIconAnimation[PreGameLib.CodeEnumPlayerPathType.Soldier] = 1120
	c_pathIconAnimation[PreGameLib.CodeEnumPlayerPathType.Scientist] = 1122
	c_pathIconAnimation[PreGameLib.CodeEnumPlayerPathType.Settler] = 6670

	if g_arActors.pathIcon and c_pathIconAnimation[self.iSelectedPath] then
		g_arActors.pathIcon:Animate(0, c_pathIconAnimation[self.iSelectedPath], 0, true, false)
	end
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

function Character:OnRacePanelToggle(wndHandler, wndControl)
	self.wndRacePicker:Show(wndControl:IsChecked())
	self.wndControlFrame:FindChild("GlowAssets"):Show(wndControl:IsChecked())
	wndControl:FindChild("AnimOverlay"):Show(wndControl:IsChecked())
	self.wndControlFrame:FindChild("ClassOptionToggle"):FindChild("AnimOverlay"):Show(false)
	self.wndControlFrame:FindChild("PathOptionToggle"):FindChild("AnimOverlay"):Show(false)
end

function Character:OnClassPanelToggle(wndHandler, wndControl)
	self.wndClassPicker:Show(wndControl:IsChecked())
	self.wndControlFrame:FindChild("GlowAssets"):Show(wndControl:IsChecked())
	wndControl:FindChild("AnimOverlay"):Show(wndControl:IsChecked())
	self.wndControlFrame:FindChild("RaceOptionToggle"):FindChild("AnimOverlay"):Show(false)
	self.wndControlFrame:FindChild("PathOptionToggle"):FindChild("AnimOverlay"):Show(false)
end

function Character:OnPathPanelToggle(wndHandler, wndControl)
	self.wndPathPicker:Show(wndControl:IsChecked())
	self.wndControlFrame:FindChild("GlowAssets"):Show(wndControl:IsChecked())
	wndControl:FindChild("AnimOverlay"):Show(wndControl:IsChecked())
	self.wndControlFrame:FindChild("RaceOptionToggle"):FindChild("AnimOverlay"):Show(false)
	self.wndControlFrame:FindChild("ClassOptionToggle"):FindChild("AnimOverlay"):Show(false)
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
function Character:OnCustomizeBtn()
    self:SetVisibleCustomizeForms()

	if g_arActors.primary then
		self.arCustomizeLookOptions = g_arActors.primary:GetLooks()
		self.arCustomizeBoneOptions = g_arActors.primary:GetBones()
		self.arCustomizeBoneOptionsPrev = g_arActors.primary:GetBones() -- used to restore previous bones if the player cancels customization
	end

	self.wndCustAdvanced:Show(false)

	self:FillCustomizePagination()

	g_cameraSlider = 0.8
	g_arActors.mainScene:Animate(0, g_cameraAnimation, 0, true, false, 0, g_cameraSlider)
	g_arActors.primary:Animate(0, c_customizePlayerAnimation, 0, true, false)
	g_arActors.mainScene:AttachCamera(7)
end

---------------------------------------------------------------------------------------------------
function Character:OnRandomizeBtn()

	for idx, entry in pairs(self.wndCustPaginationList:FindChild("Content"):GetChildren()) do
		if entry:FindChild("CustomizePaginationBtn") ~= nil then
			entry:FindChild("CustomizePaginationBtn"):SetCheck(false)
		end

		if entry:FindChild("AnimOverlay") ~= nil then
			entry:FindChild("AnimOverlay"):Show(false)
			entry:FindChild("SelectedArrow"):Show(false)
		end
		if entry:FindChild("AnimOverlayAdvanced") ~= nil then
			entry:FindChild("AnimOverlayAdvanced"):Show(false)
			entry:FindChild("SelectedArrowAdvanced"):Show(false)
		end
	end

	self.wndCustOptionList:Show(false)
	self.wndCustAdvanced:Show(false)
	self.wndCustOptionUndoBtn:Enable(false)

	if g_arActors.primary then
		self.arCustomizeLookOptions = g_arActors.primary:GetLooks()

		for i, option in pairs(self.arCustomizeLookOptions) do
			option.valueIdx = math.random( 1, option.count );
			g_arActors.primary:SetLook(option.sliderId, option.values[ option.valueIdx ] )
			g_arActors.shadow:SetLook(option.sliderId, option.values[ option.valueIdx ] )
		end
	else
		self.arCustomizeLookOptions = {}
		self.arCustomizeBoneOptions = {}
		self.arCustomizeBoneOptionsPrev = {}
	end
end

---------------------------------------------------------------------------------------------------
function Character:OnNameChanged()
	self.strName = self.wndNameEntry:GetText()
	local bIsNameValid = CharacterScreenLib.IsCharacterNameValid(self.strName)
	g_controls:FindChild("EnterBtn"):Enable(string.len(self.strName) > 0 and bIsNameValid)
	self.wndName:FindChild("CharacterNameText"):Show(self.strName ~= "")

	if string.len(self.strName) > 0 and self.arCharacterCreateOptions[self.characterCreateIndex] ~= nil and self.iSelectedPath ~= nil and bIsNameValid then
		self.wndName:FindChild("CheckMarkIcon"):SetSprite("CRB_CharacterCreateSprites:sprCharC_NameCheckYes")
		g_controls:FindChild("EnterForm"):FindChild("EnterLabel"):SetTextColor(ApolloColor.new("ff72f2a0"))
		self.wndName:FindChild("CharacterNameText"):Show(false)
		return
	elseif string.len(self.strName) == 0 then
		self.wndName:FindChild("CheckMarkIcon"):SetSprite("")
	else
		self.wndName:FindChild("CheckMarkIcon"):SetSprite("CRB_CharacterCreateSprites:sprCharC_NameCheckNo")
	end

	g_controls:FindChild("EnterForm"):FindChild("EnterLabel"):SetTextColor(ApolloColor.new("ff3c524f"))
end

---------------------------------------------------------------------------------------------------
function Character:OnRotateCatcherDown(wndHandler, wndControl, iButton, x, y, bDouble)
	if wndHandler ~= wndControl then return false end
	self.nStartPoint = x
	self.bRotateEngaged = true
end

function Character:OnRotateCatcherUp(wndHandler, wndControl, iButton, x, y)
	self.bRotateEngaged = false
end

function Character:OnRotateCatcherMove(wndHandler, wndControl, x, y)
	if self.bRotateEngaged and g_arActors.primary ~= nil then

		if x > 	self.nStartPoint then
			g_nCharCurrentRot = g_nCharCurrentRot + (x - self.nStartPoint)/480
		else
			g_nCharCurrentRot = g_nCharCurrentRot - (self.nStartPoint - x)/480
		end

		while g_nCharCurrentRot < 0 do
			g_nCharCurrentRot = g_nCharCurrentRot + 1
		end

		while g_nCharCurrentRot > 1 do
			g_nCharCurrentRot = g_nCharCurrentRot - 1
		end

		g_arActors.characterAttach:Animate(0, 1120, 0, true, false, 0, g_nCharCurrentRot)

		self.nStartPoint = x
	end
end

function Character:OnRotateCatcherMouseWheel(wndHandler, wndControl, x, y, fAmount)
	-- wndHandler and wndControl should be the catcher window
	-- x and y are the cursor position in window space
	-- fAmount is how far the wheel was moved (can be negative)

	g_cameraSlider = g_cameraSlider + fAmount * .05
	if g_cameraSlider < 0 then
		g_cameraSlider = 0
	end

	if g_cameraSlider > 1 then
		g_cameraSlider = 1
	end

	g_arActors.mainScene:Animate(0, g_cameraAnimation, 0, true, false, 0, g_cameraSlider)
end

function Character:OnSaveLoadBtn(wndHandler, wndControl)
	local strCode = g_arActors.primary:GetSliderCodes()

	if strCode ~= nil then
		self.wndCreateCodeEntry:SetText(strCode)
		self:UpdateCodeDisplay(strCode)
	end

	self:HelperHideMenus()
	self.wndCreateCode:SetData(strCode)
	self.wndCreateCode:Show(true)
end

function Character:UpdateCodeDisplay(strCode)

	local crPass = "ff2f94ac"
	local crFail = "ffcc0000"
	local tFaction = {true, "CRB_Question", crPass}
	local tRace = {true, "CRB_Question", crPass}
	local tGender = {true, "CRB_Question", crPass}

	if strCode == nil then
		local strInvalid = string.format("<P Align=\"Center\" Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</P>", crFail, Apollo.GetString("Pregame_InvalidCode"))
		self.wndCreateCode:FindChild("RaceGenderText"):SetAML(strInvalid)
		self.wndCreateCode:FindChild("UpdateCharacterCodeBtn"):Enable(false)
		return
	else
		local tResults = g_arActors.shadow:SetBySliderCodes(strCode)
		if tResults == nil then
			local strInvalid = string.format("<P Align=\"Center\" Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</P>", crFail, Apollo.GetString("Pregame_InvalidCode"))
			self.wndCreateCode:FindChild("RaceGenderText"):SetAML(strInvalid)
			self.wndCreateCode:FindChild("UpdateCharacterCodeBtn"):Enable(false)
			return
		elseif tResults.bUnsupportedVersion then
			local strInvalid = string.format("<P Align=\"Center\" Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</P>", crFail, Apollo.GetString("Pregame_OutdatedCode"))
			self.wndCreateCode:FindChild("RaceGenderText"):SetAML(strInvalid)
			self.wndCreateCode:FindChild("UpdateCharacterCodeBtn"):Enable(false)
			return
		end

		if tResults.bFactionDoesntMatch then
			tFaction[1] = false
			tFaction[3] = crFail
		end

		if tResults.bGenderDoesntMatch then
			tGender[1] = false
			tGender[3] = crFail
		end

		if tResults.bRaceDoesntMatch then
			tRace[1] = false
			tRace[3] = crFail

			if tResults.nRace == 13 then
				tGender[3] = crFail
			end
		end

		-- Format strings

		if tResults.nFaction == PreGameLib.CodeEnumFaction.Dominion then
			tFaction[2] = "CRB_Dominion"
		else
			tFaction[2] = "CRB_Exile"
		end


		if tResults.nGender == PreGameLib.CodeEnumGender.Male then
			tGender[2] = "CRB_Male"
		else
			tGender[2] = "CRB_Female"
		end

		if c_arRaceStrings[tResults.nRace] ~= nil then
			if tResults.nRace == 1 then
				tRace[2] = "CRB_DemoCC_Human"
			elseif tResults.nRace == 13 then
				tRace[2] = c_arRaceStrings[tResults.nRace][1]
				tGender[2] = "CRB_Question"
			else
				tRace[2] = c_arRaceStrings[tResults.nRace][1]
			end
		end

		local strDisplay = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">(</T>", crPass)
		local strFaction = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", tFaction[3], Apollo.GetString(tFaction[2]) .. " ")
		local strRace = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", tRace[3], Apollo.GetString(tRace[2]) .. " ")
		local strGender = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", tGender[3], Apollo.GetString(tGender[2]))
		local strEnd = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">)</T>", crPass)
		strDisplay = string.format("<P Align=\"Center\">%s</P>", PreGameLib.String_GetWeaselString(Apollo.GetString("Pregame_FactionRaceGender"), strDisplay, strFaction, strRace, strGender, strEnd))

		self.wndCreateCode:FindChild("RaceGenderText"):SetAML(strDisplay)
		self.wndCreateCode:FindChild("UpdateCharacterCodeBtn"):Enable(tRace[1] == true and tFaction[1] == true and tGender[1] == true)
	end
end

function Character:OnCloseCodeEntryBtn(wndHandler, wndControl)
	local strCode = self.wndCreateCode:GetData()
	if strCode ~= nil then
		g_arActors.shadow:SetBySliderCodes(strCode)
	end

	self.wndCreateCode:Show(false)
end

function Character:OnCharacterCodeEdit(wndHandler, wndControl, strNew, strOld)
	self:UpdateCodeDisplay(strNew)
end

function Character:OnUpdateCharacterCodeBtn(wndHandler, wndControl)
	g_arActors.primary:SetBySliderCodes(self.wndCreateCodeEntry:GetText())
	g_arActors.shadow:SetBySliderCodes(self.wndCreateCodeEntry:GetText())
	self.wndCreateCode:Show(false)
	self:OnCustomizeBtn()
end

---------------------------------------------------------------------------------------------------
-- Character Customize Character
---------------------------------------------------------------------------------------------------

function Character:FillCustomizePagination() -- we can assume this only happens when entering character create

	self.arPreviousCharacterOptions = {} -- build a table of defaults for the character. Allows us to undo.
	self.arCustomizePaginationBtns = {}
	self.wndCustPaginationList:FindChild("Content"):DestroyChildren()

	self:FillCustomizeBoneOptions() -- set up bone scaling

	for i, wnd in pairs(self.arCustomizePaginationBtns) do
		wnd:Destroy()
	end

	local arCurrentLooks = g_arActors.primary:GetLooks()

	if self.arCustomizeLookOptions == nil or #self.arCustomizeLookOptions < 1  then
		self.wndCustOptionPanel:Show(false)
		return
	elseif self.arCustomizeLookOptions ~= arCurrentLooks then
		self.arCustomizeLookOptions = arCurrentLooks
	end

	local nListHeight = 0

	local nFaces = 1
	local bFaces = false
	for idxFaces, option in pairs(self.arCustomizeLookOptions) do
		if option.sliderId == 1 or option.sliderId == 21 or option.sliderId == 22 then -- faces
			nFaces = idxFaces
			bFaces = true
			local wnd = Apollo.LoadForm(self.xmlDoc, "CustomizePaginationEntryBones", self.wndCustPaginationList:FindChild("Content"), self)

			wnd:FindChild("DebugLabel"):SetText("")
			wnd:SetData(option)
			wnd:FindChild("CustomizePaginationBtn"):SetText("   " .. option.name)

			if wnd:FindChild("AnimOverlay") ~= nil then
				wnd:FindChild("AnimOverlay"):Show(false)
				wnd:FindChild("SelectedArrow"):Show(false)
			end
			if wnd:FindChild("AnimOverlayAdvanced") ~= nil then
				wnd:FindChild("AnimOverlayAdvanced"):Show(false)
				wnd:FindChild("SelectedArrowAdvanced"):Show(false)
			end


			table.insert(self.arCustomizePaginationBtns, wnd)

			local t = {option, option.valueIdx} -- needs to be updated if the player modifies, then goes into create
			table.insert(self.arPreviousCharacterOptions, t)  -- build a table of defaults for the character. Allows us to completely undo.

			local itemRectL, itemRectT, itemRectR, itemRectB = wnd:GetRect()
			local nHeight = itemRectB - itemRectT
			nListHeight = nListHeight + nHeight

			if Apollo.GetConsoleVariable("ui.createScreenShowSliderValues") == true then
				wnd:FindChild("DebugLabel"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("Pregame_SliderOptions"), option.sliderId, option.valueIdx))
			end
		end
	end

	for i, option in ipairs(self.arCustomizeLookOptions) do -- we want these to appear in order.
		local bNotFaceSlider = (bFaces == false) or (option.sliderId ~= 1 and option.sliderId ~= 21 and option.sliderId ~= 22)
		if bNotFaceSlider == true then -- faces
			local wnd = Apollo.LoadForm(self.xmlDoc, "CustomizePaginationEntry", self.wndCustPaginationList:FindChild("Content"), self)
			wnd:FindChild("DebugLabel"):SetText("")
			wnd:SetData(option)
			wnd:FindChild("CustomizePaginationBtn"):SetText("   " .. option.name)

			if wnd:FindChild("AnimOverlay") ~= nil then
				wnd:FindChild("AnimOverlay"):Show(false)
				wnd:FindChild("SelectedArrow"):Show(false)
			end
			if wnd:FindChild("AnimOverlayAdvanced") ~= nil then
				wnd:FindChild("AnimOverlayAdvanced"):Show(false)
				wnd:FindChild("SelectedArrowAdvanced"):Show(false)
			end


			table.insert(self.arCustomizePaginationBtns, wnd)

			local t = {option, option.valueIdx} -- needs to be updated if the player modifies, then goes into create
			table.insert(self.arPreviousCharacterOptions, t)  -- build a table of defaults for the character. Allows us to completely undo.

			local itemRectL, itemRectT, itemRectR, itemRectB = wnd:GetRect()
			local nHeight = itemRectB - itemRectT
			nListHeight = nListHeight + nHeight

			if Apollo.GetConsoleVariable("ui.createScreenShowSliderValues") == true then
				wnd:FindChild("DebugLabel"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("Pregame_SliderOptions"), option.sliderId, option.valueIdx))
			end
		end
	end

	-- the frame is v-anchored to .5 top and bottom
	-- the list is v-anchored to 0 and 1
	local wndList = self.wndCustPaginationList:FindChild("Content")
	local l,t,r,b = wndList:GetAnchorOffsets()
	local lFrame, tFrame, rFrame, bFrame = self.wndCustPaginationList:GetAnchorOffsets()
	local nTotalHeight = nListHeight+t-b

	self.wndCustPaginationList:SetAnchorOffsets(lFrame, -nTotalHeight/2, rFrame, nTotalHeight/2)

	self.wndCustPaginationList:FindChild("Content"):ArrangeChildrenVert()

	local wndFirstOption = self.arCustomizePaginationBtns[1]
	self.wndCustOptionPanel:SetData(wndFirstOption:GetData())
	self.wndCustOptionUndoBtn:SetData(wndFirstOption:GetData().valueIdx) -- set the old option to undo--]]
	self.iCurrentPage = 1
	self.wndCustOptionUndoBtn:Enable(false) -- disable undo until the player makes a change
	self:FillCustomizeOptions(true)
end

---------------------------------------------------------------------------------------------------
function Character:FillCustomizeOptions(bNoShow)
	self.wndCustOptionList:FindChild("CustomizeContent"):DestroyChildren()
	self.wndCustOptionList:FindChild("CustomizeContent"):RecalculateContentExtents()
	iOption = self.wndCustOptionPanel:GetData() -- putting data on the frame so we know which option we're changing
	self.arCustomizeOptionBtns = {}

	local nEntryHeight = 0
	local wndSel = nil
	for i = 1, iOption.count do  -- count is the number of choices for an option
		local wnd = Apollo.LoadForm(self.xmlDoc, "CustomizeOptionEntry", self.wndCustOptionList:FindChild("CustomizeContent"), self)
		g_arActors.shadow:SetLook(iOption.sliderId, iOption.values[ i ] ) -- set the shadow actor to each option

		wnd:FindChild("CustomizeEntryPreview"):SetCostumeToActor(g_arActors.shadow) -- set a portrait on each button
		wnd:FindChild("CustomizeEntryPreview"):SetItemsByCreationId( self.arCharacterCreateOptions[self.characterCreateIndex].characterCreateId )
		wnd:FindChild("CustomizeEntryPreview"):SetModelSequence(c_customizePlayerAnimation)

		if iOption.sliderId == 25 then -- body type
			wnd:FindChild("CustomizeEntryPreview"):SetCamera("Datachron")
		else
			wnd:FindChild("CustomizeEntryPreview"):SetCamera("Portrait")
		end

		wnd:SetData(i)
		table.insert(self.arCustomizeOptionBtns, wnd)
		if i == iOption.valueIdx then --value.Idx is the current setting for an option
			wndSel = wnd
			wnd:FindChild("CustomizeEntryBtn"):SetCheck(true)
		end

		nEntryHeight = wnd:GetHeight()
	end

	if iOption.sliderId == 1 then -- faces
		self.wndCustOptionUndoBtn:Show(true)

		-- get current slider positions here for undo (clears on pagination)
		self.arPreviousSliderOptions = {}
		for i, sliderWnd in pairs(self.arWndCustomizeBoneOptions) do
			sliderWnd:FindChild("SliderUndoBtn"):Show(false)
			local t = {}
			t.type = sliderWnd:GetData()
			t.value = sliderWnd:FindChild("CustomizeBoneSliderBar"):GetValue() -- this info does exist on a separate table; using the slider to ensure the data matches the model
			sliderWnd:FindChild("Value"):SetText(string.format("%.2f", t.value))
			sliderWnd:FindChild("SliderProgBar"):SetProgress(t.value + 1)
			table.insert(self.arPreviousSliderOptions, t)
		end

	else
		self.wndCustOptionUndoBtn:Show(true)
		self.wndCustAdvanced:Show(false)
	end

	g_arActors.shadow:SetLook(iOption.sliderId, iOption.values[iOption.valueIdx] ) -- return to the initial model from opening this panel
	self.wndCustOptionList:FindChild("CustomizeContent"):ArrangeChildrenTiles()

	if wndSel then
		self.wndCustOptionList:FindChild("CustomizeContent"):EnsureChildVisible(wndSel)
	end

	if bNoShow then
		self.wndCustOptionList:Show(false)
	else
		self.wndCustOptionList:Show(true)
	end
end

---------------------------------------------------------------------------------------------------
function Character:OnCustomizePagination(wndHandler, wndCtrl)
	local wndContainer = nil
	local option = nil


	if wndCtrl ~= nil then -- from click
		wndContainer = wndCtrl:GetParent()
		option = wndContainer:GetData()
		self.wndCustPaginationList:FindChild("SideGlow"):Show(true)
	else -- from function goes in here - used for arrows
		option = self.arCustomizePaginationBtns[self.iCurrentPage]:GetData()
	end

	for idx, window in pairs(self.arCustomizePaginationBtns) do -- reset the buttons; programatic radio sets won't do this by themselves
		local iValue = window:GetData()
		window:FindChild("CustomizePaginationBtn"):SetCheck(false)

		if window:FindChild("AnimOverlay") ~= nil then
			window:FindChild("AnimOverlay"):Show(false)
			window:FindChild("SelectedArrow"):Show(false)
		end
		if window:FindChild("AnimOverlayAdvanced") ~= nil then
			window:FindChild("AnimOverlayAdvanced"):Show(false)
			window:FindChild("SelectedArrowAdvanced"):Show(false)
		end

		if option == iValue then
			window:FindChild("CustomizePaginationBtn"):SetCheck(true)

			if window:FindChild("AnimOverlay") ~= nil then
				window:FindChild("AnimOverlay"):Show(true)
				window:FindChild("SelectedArrow"):Show(true)
			end

			self.iCurrentPage = idx
		end
	end

	self.wndCustOptionPanel:SetData(option)
	self.wndCustOptionUndoBtn:SetData(option.valueIdx) -- set the old option to undo
	self.wndCustOptionUndoBtn:Enable(false) -- disable undo until the player makes a change

	self:FillCustomizeOptions()
end

---------------------------------------------------------------------------------------------------
function Character:OnCustomizePaginationUncheck(wndHandler, wndCtrl)
	self.wndCustOptionList:Show(false)
	wndCtrl:FindChild("AnimOverlay"):Show(false)
	wndCtrl:FindChild("SelectedArrow"):Show(false)
	self.wndCustPaginationList:FindChild("SideGlow"):Show(false)
end

---------------------------------------------------------------------------------------------------
function Character:OnCustomizeOption(wndHandler, wndCtrl)
	local wndContainer = wndCtrl:GetParent()
	local iEntry = wndContainer:GetData()
	local option = self.wndCustOptionPanel:GetData()
	local iPrevious = self.wndCustOptionUndoBtn:GetData() -- get the initial value

	for idx, window in pairs(self.arCustomizeOptionBtns) do -- reset the buttons; programatic radio sets won't do this by themselves
		window:FindChild("CustomizeEntryBtn"):SetCheck(false)
		--window:FindChild("CustomizeBack"):SetSprite(kcrNormalBack)
	end

	wndCtrl:SetCheck(true) -- set the chosen one
	--wndContainer:FindChild("CustomizeBack"):SetSprite(kcrSelectedBack)

	option.valueIdx = iEntry
	g_arActors.primary:SetLook(option.sliderId, option.values[ option.valueIdx ] )	-- set new
	g_arActors.shadow:SetLook(option.sliderId, option.values[ option.valueIdx ] )	-- set new

	if iEntry == iPrevious then -- picked the same one they loaded the panel with
		self.wndCustOptionUndoBtn:Enable(false)
	else -- picked something new
		self.wndCustOptionUndoBtn:Enable(true)
	end


	if Apollo.GetConsoleVariable("ui.createScreenShowSliderValues") == true then
		local wndBtn = self.wndCustPaginationList:FindChild("Content"):FindChildByUserData(option)
		wndBtn:FindChild("DebugLabel"):SetText(PreGameLib.String_GetWeaselString(Apollo.GetString("Pregame_SliderOptions"), option.sliderId, option.valueIdx))
	end
end

---------------------------------------------------------------------------------------------------
function Character:OnUndoBtn(wndHandler, wndCtrl)
	local iPrevious = wndCtrl:GetData() -- get the previous selection's number
	local option = self.wndCustOptionPanel:GetData()	-- get the type we're viewing

	for idx, window in pairs(self.arCustomizeOptionBtns) do -- reset the buttons
		local wndValue = window:GetData()
		if iPrevious == wndValue then
			window:FindChild("CustomizeEntryBtn"):SetCheck(true)
			--window:FindChild("CustomizeBack"):SetSprite(kcrSelectedBack)
		else
			window:FindChild("CustomizeEntryBtn"):SetCheck(false)
			--window:FindChild("CustomizeBack"):SetSprite(kcrNormalBack)
		end
	end

	option.valueIdx = iPrevious
	g_arActors.primary:SetLook(option.sliderId, option.values[ option.valueIdx ] )	 -- set previous
	g_arActors.shadow:SetLook(option.sliderId, option.values[ option.valueIdx ] )	 -- set previous
	self.wndCustOptionUndoBtn:Enable(false)
end

---------------------------------------------------------------------------------------------------
function Character:OnAcceptCustomizeBtn()
	local scale = 1.0
	local position = Vector3:Zero()
	local rotation = Vector3:Zero()

	--g_arActors.primary:SetPosition( scale, position + g_tPositionOffset, rotation )
	self:ConfigureCreateModelSettings()

	self:SetCreateForms()

	g_cameraSlider = 0
	g_arActors.mainScene:Animate(0, g_cameraAnimation, 0, true, false, 0, g_cameraSlider)
end

---------------------------------------------------------------------------------------------------
function Character:OnCancelCustomizeBtn()
	local scale = 1.0
	local position = Vector3:Zero()
	local rotation = Vector3:Zero()

	--g_arActors.primary:SetPosition( scale, position + g_tPositionOffset, rotation )
	self:ConfigureCreateModelSettings()

	for i = 1, #self.arPreviousCharacterOptions do
		g_arActors.primary:SetLook(self.arPreviousCharacterOptions[i][1].sliderId, self.arPreviousCharacterOptions[i][1].values[ self.arPreviousCharacterOptions[i][2] ] )
		g_arActors.shadow:SetLook(self.arPreviousCharacterOptions[i][1].sliderId, self.arPreviousCharacterOptions[i][1].values[ self.arPreviousCharacterOptions[i][2] ] )
	end

	for i, bone in ipairs(self.arCustomizeBoneOptionsPrev) do
		g_arActors.primary:SetBone(bone.sliderId, bone.value)
		g_arActors.shadow:SetBone(bone.sliderId, bone.value)
	end

	for idx, entry in pairs(self.wndCustPaginationList:FindChild("Content"):GetChildren()) do
		if entry:FindChild("CustomizePaginationBtn") ~= nil then
			entry:FindChild("CustomizePaginationBtn"):SetCheck(false)

			if entry:FindChild("AnimOverlay") ~= nil then
				entry:FindChild("AnimOverlay"):Show(false)
				entry:FindChild("SelectedArrow"):Show(false)
			end
			if entry:FindChild("AnimOverlayAdvanced") ~= nil then
				entry:FindChild("AnimOverlayAdvanced"):Show(false)
				entry:FindChild("SelectedArrowAdvanced"):Show(false)
			end
		end
	end

	self:OnResetSlidersBtn()
	self.wndCustPaginationList:FindChild("SideGlow"):Show()
	self.wndCustOptionList:Show(false)
	self.wndCustAdvanced:Show(false)
end

---------------------------------------------------------------------------------------------------
function Character:FillCustomizeBoneOptions()
	for idx, wnd in ipairs(self.arWndCustomizeBoneOptions) do
		wnd:Destroy()
	end
	self.arWndCustomizeBoneOptions = {}

	local wndHolder = self.wndCustAdvanced:FindChild("SliderListWindow")

	for i, bone in ipairs(self.arCustomizeBoneOptions) do -- we want these to appear in order
		local wnd = Apollo.LoadForm(self.xmlDoc, "CustomizeBoneOption", wndHolder, self)
		wnd:FindChild("Label"):SetText(bone.name)
		wnd:SetData(bone.sliderId)
		wnd:FindChild("CustomizeBoneSliderBar"):SetValue(bone.value)
		wnd:FindChild("Value"):SetText(string.format("%.2f", bone.value))
		wnd:FindChild("SliderProgBar"):SetFloor(0)
		wnd:FindChild("SliderProgBar"):SetMax(2)
		wnd:FindChild("SliderProgBar"):SetProgress(bone.value + 1)
		table.insert(self.arWndCustomizeBoneOptions, wnd)
	end

	wndHolder:ArrangeChildrenVert()
end

---------------------------------------------------------------------------------------------------
function Character:OnToggleFaceSliderCheck(wndHandler, wndCtrl)

	for idx, entry in pairs(self.wndCustPaginationList:FindChild("Content"):GetChildren()) do
		if entry:FindChild("CustomizePaginationBtn") ~= nil then
			entry:FindChild("CustomizePaginationBtn"):SetCheck(false)
		end

		if entry:FindChild("AnimOverlay") ~= nil then
			entry:FindChild("AnimOverlay"):Show(false)
			entry:FindChild("SelectedArrow"):Show(false)
		end
		if entry:FindChild("AnimOverlayAdvanced") ~= nil then
			entry:FindChild("AnimOverlayAdvanced"):Show(false)
			entry:FindChild("SelectedArrowAdvanced"):Show(false)
		end
	end

	self.wndCustPaginationList:FindChild("SideGlow"):Show(true)
	wndCtrl:FindChild("AnimOverlayAdvanced"):Show(true)
	wndCtrl:FindChild("SelectedArrowAdvanced"):Show(true)
	self.wndCustOptionList:Show(false)
	self.wndCustAdvanced:Show(true)
end

function Character:OnToggleFaceSliderUncheck(wndHandler, wndCtrl)
	self.wndCustAdvanced:Show(false)
	self.wndCustPaginationList:FindChild("SideGlow"):Show(false)
	wndCtrl:FindChild("AnimOverlayAdvanced"):Show(false)
	wndCtrl:FindChild("SelectedArrowAdvanced"):Show(false)
end

---------------------------------------------------------------------------------------------------
function Character:OnSliderBarChanging(wnd, wndHandler, value, oldvalue)
	local wndParent = wnd:GetParent()
	wndParent:FindChild("SliderProgBar"):SetProgress(value + 1)
	return true
end


---------------------------------------------------------------------------------------------------
function Character:OnSliderBarChanged(wnd, wndHandler, value, oldvalue)
	local wndParent = wnd:GetParent()
	local option = wndParent:GetData()

	if g_arActors.primary then
		g_arActors.primary:SetBone(option, value)
	end

	if g_arActors.shadow then
		g_arActors.shadow:SetBone(option, value)
	end

	local bHit = false
	for i, sliderEntry in pairs(self.arPreviousSliderOptions) do
		if option == sliderEntry.type then
			if value ~= sliderEntry.value then
				wndParent:FindChild("SliderUndoBtn"):SetData(sliderEntry.value)
				wndParent:FindChild("SliderUndoBtn"):Show(true)
			else
				wndParent:FindChild("SliderUndoBtn"):Show(false)
			end

			wndParent:FindChild("Value"):SetText(string.format("%.2f", value))
			bHit = true
		end
	end

	if not bHit then -- Error state, sometimes for the first pick
		self:OnResetSlidersBtn()
	end

	self.arCustomizeBoneOptions	= g_arActors.primary:GetBones() -- update the model
end

---------------------------------------------------------------------------------------------------
function Character:OnSliderUndoBtn(wndHandler, wndCtrl)
	local wndParent = wndCtrl:GetParent()
	local option = wndParent:GetData()
	local value = wndCtrl:GetData()

	wndParent:FindChild("CustomizeBoneSliderBar"):SetValue(value)
	wndParent:FindChild("Value"):SetText(string.format("%.2f", value))
	wndParent:FindChild("SliderProgBar"):SetProgress(value + 1)

	if g_arActors.primary then
		g_arActors.primary:SetBone(option, value)
	end

	if g_arActors.shadow then
		g_arActors.shadow:SetBone(option, value)
	end

	wndCtrl:Show(false)

	self.arCustomizeBoneOptions	= g_arActors.primary:GetBones() -- update the model
end

---------------------------------------------------------------------------------------------------
function Character:OnResetSlidersBtn()
	self.arPreviousSliderOptions = {}
	for i, sliderWnd in pairs(self.arWndCustomizeBoneOptions) do
		sliderWnd:FindChild("CustomizeBoneSliderBar"):SetValue(0)
		sliderWnd:FindChild("Value"):SetText("0.00")
		sliderWnd:FindChild("SliderUndoBtn"):Show(false)
		sliderWnd:FindChild("SliderProgBar"):SetProgress(1)
		local t = {}
		t.type = sliderWnd:GetData()
		t.value = sliderWnd:FindChild("CustomizeBoneSliderBar"):GetValue() -- this info does exist on a separate table; using the slider to ensure the data matches the model
		table.insert(self.arPreviousSliderOptions, t)
	end

	self:ResetBones()
	self.arCustomizeBoneOptions	= g_arActors.primary:GetBones() -- this is a "permanent" change so we reset the table
end

---------------------------------------------------------------------------------------------------
function Character:ResetBones() -- don't reset the table so the player can toggle back and forth
	for i, bone in ipairs(self.arCustomizeBoneOptions) do
		g_arActors.primary:SetBone(bone.sliderId, 0)
		g_arActors.shadow:SetBone(bone.sliderId, 0)
	end
end

---------------------------------------------------------------------------------------------------
function Character:OnOptionEnter(wndHandler, wndControl)
	--wndControl:ChangeArt("CRB_TalentSprites:btnTalentSelect")
end

function Character:OnOptionExit(wndHandler, wndControl)
	--wndControl:ChangeArt(kcrNormalButton)
end

---------------------------------------------------------------------------------------------------
-- Options Buttons
---------------------------------------------------------------------------------------------------
function Character:OnLoginOptions(wndHandler, wndControl)
	PreGameLib.InvokeOptions()
end

---------------------------------------------------------------------------------------------------
-- Create Fail Events and Handlers
---------------------------------------------------------------------------------------------------
function Character:OnCreateCharacterFailed(nReason)

	local strReason = Apollo.GetString("Pregame_DefaultError")


	if nReason == PreGameLib.CodeEnumCharacterModifyResults.CreateFailed_UniqueName then
		strReason = Apollo.GetString("Pregame_NameUnavailable")
	elseif nReason == PreGameLib.CodeEnumCharacterModifyResults.CreateFailed_CharacterOnline then
		strReason = Apollo.GetString("PreGame_CreateErrorCharacterOnline")
	elseif nReason == PreGameLib.CodeEnumCharacterModifyResults.CreateFailed_AccountFull then
		strReason = Apollo.GetString("Pregame_AccountFull")
	elseif nReason == PreGameLib.CodeEnumCharacterModifyResults.CreateFailed_InvalidName then
		strReason = Apollo.GetString("Pregame_InvalidError")
	elseif nReason == PreGameLib.CodeEnumCharacterModifyResults.CreateFailed_Faction then
		strReason = Apollo.GetString("Pregame_OpposingFaction")
	elseif nReason == PreGameLib.CodeEnumCharacterModifyResults.CreateFailed_Internal  then
		strReason = Apollo.GetString("Pregame_DefaultError")
	elseif nReason == PreGameLib.CodeEnumCharacterModifyResults.CreateFailed then
		strReason = Apollo.GetString("Pregame_DefaultError")
	end


	self.wndCreateFailed:FindChild("CreateError_Body"):SetText(strReason)
	Apollo.CreateTimer("CreateFailedTimer", 5.0, false)
	Apollo.StartTimer("CreateFailedTimer")
	self.wndCreateFailed:Show(true)

	return true
end

function Character:OnCreateFailedTimer()
	self.wndCreateFailed:Show(false)
end

function Character:OnCreateErrorClose(wndHandler, wndCtrl)
	Apollo.StopTimer("CreateFailedTimer")
	self.wndCreateFailed:Show(false)
end

function Character:OnRealmBroadcast(strRealmBroadcast, nTier)
	self:HelperServerMessages(strRealmBroadcast)
	if nTier < 2 then
		Apollo.StopTimer("RealmBroadcastTimer")
		Apollo.StartTimer("RealmBroadcastTimer")

		self.wndRealmBroadcast:FindChild("RealmMessage_Body"):SetText(strRealmBroadcast)
		self.wndRealmBroadcast:Show(true)
	end
end

function Character:OnRealmBroadcastTimer()
	self.wndRealmBroadcast:Show(false)
end

function Character:OnRealmBroadcastClose( wndHandler, wndControl, eMouseButton )
	Apollo.StopTimer("RealmBroadcastTimer")
	self.wndRealmBroadcast:Show(false)
end


---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
function Character:BuildOptionsMap()
	self.mapCharacterCreateOptions = {}
	for idx, tCharacterOption in pairs(CharacterScreenLib.GetCharacterCreation(self.nCreationTable)) do
		if not self.mapCharacterCreateOptions[tCharacterOption.factionId] then
			self.mapCharacterCreateOptions[tCharacterOption.factionId] = {}
		end
		if not self.mapCharacterCreateOptions[tCharacterOption.factionId][tCharacterOption.raceId] then
			self.mapCharacterCreateOptions[tCharacterOption.factionId][tCharacterOption.raceId] = {}
		end
		if not self.mapCharacterCreateOptions[tCharacterOption.factionId][tCharacterOption.raceId][tCharacterOption.classId] then
			self.mapCharacterCreateOptions[tCharacterOption.factionId][tCharacterOption.raceId][tCharacterOption.classId] = {}
		end

		self.mapCharacterCreateOptions[tCharacterOption.factionId][tCharacterOption.raceId][tCharacterOption.classId][tCharacterOption.genderId] = idx
	end
end

--idFaction is required.  If any of the other variables aren't set, we'll get a random value
function Character:GetCharacterCreateId(idFaction, idRace, idClass, idGender)
	if not self.mapCharacterCreateOptions then
		self:BuildOptionsMap()
	end

	--if we pass no race or an invalid one, get a new one
	if not idRace or not self.mapCharacterCreateOptions[idFaction][idRace] then
		local tRaces = {}
		for idx, idOption in pairs(self.mapCharacterCreateOptions[idFaction]) do
			if not idClass or self.mapCharacterCreateOptions[idFaction][idx][idClass] then
				table.insert(tRaces, idx)
			end
		end
		idRace = tRaces[math.random(1, #tRaces)]
	end

	--if we pass no class or an invalid one, get a new one
	if not idClass or not self.mapCharacterCreateOptions[idFaction][idRace][idClass] then
		local tClasses = {}
		for idx, idOption in pairs(self.mapCharacterCreateOptions[idFaction][idRace]) do
			table.insert(tClasses, idx)
		end

		idClass = tClasses[math.random(1, #tClasses)]
	end

	-- if we pass a gender....you get the idea
	if not idGender or not self.mapCharacterCreateOptions[idFaction][idRace][idClass][idGender] then
		local tGenders = {}
		for idx, idOption in pairs(self.mapCharacterCreateOptions[idFaction][idRace][idClass]) do
			table.insert(tGenders, idx)
		end

		idGender = tGenders[math.random(1, #tGenders)]
	end

	return self.mapCharacterCreateOptions[idFaction][idRace][idClass][idGender]
end


function Character:GetSelectedOptionsCopy()
	if 	self.arCharacterCreateOptions == nil then -- initial load; TODO: helpers would be in here.
		self.arCharacterCreateOptions = CharacterScreenLib.GetCharacterCreation(self.nCreationTable)
		self:BuildOptionsMap()
	end

	local selected = self.arCharacterCreateOptions[self.characterCreateIndex]
	if selected == nil then
		return {}
	end

	key = {}
	for idx, something in pairs(selected) do
		key[idx]=something
	end

	return key
end

function Character:HelperHideMenus()
	self.wndRacePicker:Show(false)
	self.wndClassPicker:Show(false)
	self.wndPathPicker:Show(false)
	self.wndCreateFailed:Show(false)
	self.wndControlFrame:FindChild("GlowAssets"):Show(false)

	self.wndCustOptionList:Show(false)
	self.wndCustAdvanced:Show(false)

	self.wndControlFrame:FindChild("RaceOptionToggle"):SetCheck(false)
	self.wndControlFrame:FindChild("ClassOptionToggle"):SetCheck(false)
	self.wndControlFrame:FindChild("PathOptionToggle"):SetCheck(false)

	self.wndCustPaginationList:FindChild("SideGlow"):Show(false)

	for idx, entry in pairs(self.wndCustPaginationList:FindChild("Content"):GetChildren()) do
		if entry:FindChild("CustomizePaginationBtn") ~= nil then
			entry:FindChild("CustomizePaginationBtn"):SetCheck(false)
		end

		if entry:FindChild("AnimOverlay") ~= nil then
			entry:FindChild("AnimOverlay"):Show(false)
			entry:FindChild("SelectedArrow"):Show(false)
		end
		if entry:FindChild("AnimOverlayAdvanced") ~= nil then
			entry:FindChild("AnimOverlayAdvanced"):Show(false)
			entry:FindChild("SelectedArrowAdvanced"):Show(false)
		end

	end
end

function Character:HelperConvertToTime(nArg)
	local nMinutes = nArg/60
	local nHours = nMinutes/60
	local strTime = ""

	if nMinutes > 1 then -- at least one minute
		if nHours > 1 then
			local nMinutesExcess = nMinutes - math.floor(nHours)*60
			strMinutes = PreGameLib.String_GetWeaselString(Apollo.GetString("BuildMap_Mins"), math.floor(nMinutesExcess))
			strTime = PreGameLib.String_GetWeaselString(Apollo.GetString("BuildMap_Hours"), math.floor(nHours)) .. ", " .. strMinutes
		else
			strTime = PreGameLib.String_GetWeaselString(Apollo.GetString("BuildMap_Mins"), math.floor(nMinutes))
		end
	else
		strTime = Apollo.GetString("GuildPerk_LessThanAMinute")
	end

	return strTime
end

function Character:HelperServerMessages(strExtra)
	local strAllMessage = ""
	local strColor = "xkcdBurntYellow"
	if CharacterScreenLib.WasDisconnectedForLag() then
		strColor = "AddonError"
		strAllMessage = Apollo.GetString("CharacterSelect_LagDisconnectExplain")
	else
		for idx, strMessage in ipairs(self.arServerMessages) do
			strAllMessage = strAllMessage .. strMessage .. "\n"
		end
		if strExtra ~= nil then
			strAllMessage = strAllMessage .. strExtra .. "\n"
		end
	end

	self.wndServerMessage:SetAML(string.format("<T Font=\"CRB_Interface10_B\" TextColor=\"%s\">%s</T>", strColor, strAllMessage))
	self.wndServerMessagesContainer:Show(string.len(strAllMessage or "") > 0)

	local nWidth, nHeight = self.wndServerMessage:SetHeightToContentHeight()
	local nLeft, nTop, nRight, nBottom = self.wndServerMessagesContainer:GetAnchorOffsets()
	self.wndServerMessagesContainer:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.min(75, nHeight + 5))
end

function Character:OnRealmBtn(wndHandler, wndControl)
	CharacterScreenLib.ExitToRealmSelect()
end

---------------------------------------------------------------------------------------------------
-- Character instance
---------------------------------------------------------------------------------------------------
local CharacterInst = Character:new()
CharacterInst:Init()