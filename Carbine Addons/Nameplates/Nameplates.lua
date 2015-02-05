-----------------------------------------------------------------------------------------------
-- Client Lua Script for Nameplates
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "ChallengesLib"
require "Unit"
require "GameLib"
require "Apollo"
require "PathMission"
require "Quest"
require "Episode"
require "math"
require "string"
require "DialogSys"
require "PublicEvent"
require "PublicEventObjective"
require "CommunicatorLib"
require "GroupLib"
require "PlayerPathLib"
require "GuildLib"
require "GuildTypeLib"

local Nameplates = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local karDisposition =
{
	tTextColors =
	{
		[Unit.CodeEnumDisposition.Hostile] 	= ApolloColor.new("DispositionHostile"),
		[Unit.CodeEnumDisposition.Neutral] 	= ApolloColor.new("DispositionNeutral"),
		[Unit.CodeEnumDisposition.Friendly] = ApolloColor.new("DispositionFriendly"),
	},

	tTargetPrimary =
	{
		[Unit.CodeEnumDisposition.Hostile] 	= "CRB_Nameplates:sprNP_BaseSelectedRed",
		[Unit.CodeEnumDisposition.Neutral] 	= "CRB_Nameplates:sprNP_BaseSelectedYellow",
		[Unit.CodeEnumDisposition.Friendly] = "CRB_Nameplates:sprNP_BaseSelectedGreen",
	},

	tTargetSecondary =
	{
		[Unit.CodeEnumDisposition.Hostile] 	= "sprNp_Target_HostileSecondary",
		[Unit.CodeEnumDisposition.Neutral] 	= "sprNp_Target_NeutralSecondary",
		[Unit.CodeEnumDisposition.Friendly] = "sprNp_Target_FriendlySecondary",
	},

	tHealthBar =
	{
		[Unit.CodeEnumDisposition.Hostile] 	= "CRB_Nameplates:sprNP_RedProg",
		[Unit.CodeEnumDisposition.Neutral] 	= "CRB_Nameplates:sprNP_YellowProg",
		[Unit.CodeEnumDisposition.Friendly] = "CRB_Nameplates:sprNP_GreenProg",
	},

	tHealthTextColor =
	{
		[Unit.CodeEnumDisposition.Hostile] 	= "ffff8585",
		[Unit.CodeEnumDisposition.Neutral] 	= "ffffdb57",
		[Unit.CodeEnumDisposition.Friendly] = "ff9bff80",
	},
}

local knHealthRed = 0.3
local knHealthYellow = 0.5

local karConColors =  -- differential value, color
{
	{-4, ApolloColor.new("ConTrivial")},
	{-3, ApolloColor.new("ConInferior")},
	{-2, ApolloColor.new("ConMinor")},
	{-1, ApolloColor.new("ConEasy")},
	{0, ApolloColor.new("ConAverage")},
	{1, ApolloColor.new("ConModerate")},
	{2, ApolloColor.new("ConTough")},
	{3, ApolloColor.new("ConHard")},
	{4, ApolloColor.new("ConImpossible")}
}

local kcrScalingHex 	= "ffffbf80"
local kcrScalingCColor 	= CColor.new(1.0, 191/255, 128/255, 0.7)

local ksprHighLevel = "CRB_Nameplates:sprNP_HighLevel"
local ksprPvpTarget = "IconSprites:Icon_Windows_UI_CRB_Marker_Crosshair"

local karPathSprite =
{
	[PlayerPathLib.PlayerPathType_Soldier] 		= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSol",
	[PlayerPathLib.PlayerPathType_Settler] 		= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSet",
	[PlayerPathLib.PlayerPathType_Scientist] 	= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathSci",
	[PlayerPathLib.PlayerPathType_Explorer] 	= "CRB_TargetFrameRewardPanelSprites:sprTargetFrame_PathExp",
}

local knCharacterWidth 		= 8 -- the average width of a character in the font used. TODO: Not this.
local knRewardWidth 		= 23 -- the width of a reward icon + padding
local knTextHeight 			= 15 -- text window height
local knNameRewardWidth 	= 400 -- the width of the name/reward container
local knNameRewardHeight 	= 20 -- the width of the name/reward container
local knTargetRange 		= 40000 -- the distance^2 that normal nameplates should draw within (max targeting range)
local knNameplatePoolLimit	= 500 -- the window pool max size

-- Todo: break these out onto options
local kcrUnflaggedGroupmate				= ApolloColor.new("DispositionFriendlyUnflaggedDull")
local kcrUnflaggedGuildmate				= ApolloColor.new("DispositionGuildmateUnflagged")
local kcrUnflaggedAlly					= ApolloColor.new("DispositionFriendlyUnflagged")
local kcrFlaggedAlly					= ApolloColor.new("DispositionFriendly")
local kcrUnflaggedEnemyWhenUnflagged 	= ApolloColor.new("DispositionNeutral")
local kcrFlaggedEnemyWhenUnflagged		= ApolloColor.new("DispositionPvPFlagMismatch")
local kcrUnflaggedEnemyWhenFlagged		= ApolloColor.new("DispositionPvPFlagMismatch")
local kcrFlaggedEnemyWhenFlagged		= ApolloColor.new("DispositionHostile")
local kcrDeadColor 						= ApolloColor.new("crayGray")

local kcrDefaultTaggedColor = ApolloColor.new("crayGray")

-- Control types
-- 0 - custom
-- 1 - single check

local karSavedProperties =
{
	--General nameplate drawing
	["bShowMainObjectiveOnly"] = { default=true, nControlType=1, strControlName="MainShowObjectives" },
	["bShowMainGroupOnly"] = { default=true, nControlType=1, strControlName="MainShowGroup" },
	["bShowMyNameplate"] = { default=false, nControlType=1, strControlName="MainShowMine" },
	["bShowOrganization"] = { default=true, nControlType=1, strControlName="MainShowOrganization" },
	["bShowVendor"] = { default=true, nControlType=1, strControlName="MainShowVendors" },
	["bShowTaxi"] = { default=true, nControlType=1, strControlName="MainShowTaxis" },
	["bShowDispositionHostile"] = { default=true, nControlType=1, strControlName="MainShowDisposition_1" },
	["bShowDispositionNeutral"] = { default=false, nControlType=1, strControlName="MainShowDisposition_2" },
	["bShowDispositionFriendly"] = { default=false, nControlType=1, strControlName="MainShowDisposition_3" },
	["bShowDispositionFriendlyPlayer"] = { default=true, nControlType=1, strControlName="MainShowDisposition_FriendlyPlayer" },
	--Draw distance
	["nMaxRange"] = { default=70.0, nControlType=0 },
	["nMaxRangeSq"] = { default=4900.0, nControlType=0 }, -- Just a square of nMaxRange, no controls here
	--Individual
	["bShowNameMain"] = { default=true, nControlType=1, strControlName="IndividualShowName", fnCallback="OnSettingNameChanged" },
	["bShowTitle"] = { default=true, nControlType=1, strControlName="IndividualShowAffiliation", fnCallback="OnSettingTitleChanged" },
	["bShowCertainDeathMain"] = { default=true, nControlType=1, strControlName="IndividualShowCertainDeath" },
	["bShowCastBarMain"] = { default=false, nControlType=1, strControlName="IndividualShowCastBar" },
	["bShowRewardsMain"] = { default=true, nControlType=1, strControlName="IndividualShowRewardIcons", fnCallback="RequestUpdateAllNameplateRewards" },
	["bShowDuringSpeech"] = { default=true, nControlType=1, strControlName="IndividualShowDuringSpeech" },
	--Reward icons
	["bShowRewardTypeQuest"] = { default=true, nControlType=1, strControlName="ShowRewardTypeQuest", fnCallback="RequestUpdateAllNameplateRewards" },
	["bShowRewardTypeMission"] = { default=true, nControlType=1, strControlName="ShowRewardTypeMission", fnCallback="RequestUpdateAllNameplateRewards" },
	["bShowRewardTypeAchievement"] = { default=false, nControlType=1, strControlName="ShowRewardTypeAchievement", fnCallback="RequestUpdateAllNameplateRewards" },
	["bShowRewardTypeChallenge"] = { default=true, nControlType=1, strControlName="ShowRewardTypeChallenge", fnCallback="RequestUpdateAllNameplateRewards" },
	["bShowRewardTypeReputation"] = { default=false, nControlType=1, strControlName="ShowRewardTypeReputation", fnCallback="RequestUpdateAllNameplateRewards" },
	["bShowRewardTypePublicEvent"] = { default=true, nControlType=1, strControlName="ShowRewardTypePublicEvent", fnCallback="RequestUpdateAllNameplateRewards" },
	["bShowRivals"] = { default=true, nControlType=1, strControlName="ShowRewardTypeRival", fnCallback="RequestUpdateAllNameplateRewards" },
	["bShowFriends"] = { default=true, nControlType=1, strControlName="ShowRewardTypeFriend", fnCallback="RequestUpdateAllNameplateRewards" },
	--Info panel
	["bShowHealthMain"] = { default=false, nControlType=0, fnCallback="OnSettingHealthChanged" },
	["bShowHealthMainDamaged"] = { default=true, nControlType=0, fnCallback="OnSettingHealthChanged" },
	--target components
	["bShowMarkerTarget"] = { default=true, nControlType=1, strControlName="TargetedShowMarker" },
	["bShowNameTarget"] = { default=true, nControlType=1, strControlName="TargetedShowName", fnCallback="OnSettingNameChanged" },
	["bShowRewardsTarget"] = { default=true, nControlType=1, strControlName="TargetedShowRewards"},
	["bShowGuildNameTarget"] = { default=true, nControlType=1, strControlName="TargetedShowGuild", fnCallback="OnSettingTitleChanged" },
	["bShowHealthTarget"] = { default=true, nControlType=1, strControlName="TargetedShowHealth", fnCallback="OnSettingHealthChanged" },
	["bShowRangeTarget"] = { default=false, nControlType=0 },
	["bShowCastBarTarget"] = { default=true, nControlType=1, strControlName="TargetedShowCastBar" },
	--Non-targeted nameplates in combat
	["bHideInCombat"] = { default=false, nControlType=0 }
}

-----------------------------------------------------------------------------------------------
-- Local function reference declarations
-----------------------------------------------------------------------------------------------
local fnDrawHealth
local fnDrawRewards
local fnDrawCastBar
local fnDrawVulnerable
local fnColorNameplate
local fnDrawTargeting

function Nameplates:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.arPreloadUnits = {}
	o.bAddonRestoredOrLoaded = false

	o.arWindowPool = {}
	o.arUnit2Nameplate = {}
	o.arWnd2Nameplate = {}

	o.bPlayerInCombat = false
	o.guildDisplayed = nil
	o.guildWarParty = nil
	o.bRedrawRewardIcons = false

    return o
end

function Nameplates:Init()
    Apollo.RegisterAddon(self, true, Apollo.GetString("CRB_Nameplates"), {"Tooltips", "RewardIcons"})
end

function Nameplates:OnDependencyError(strDependency, strError)
	return true
end

-----------------------------------------------------------------------------------------------
-- Nameplates OnLoad
-----------------------------------------------------------------------------------------------

function Nameplates:OnLoad()
	Apollo.RegisterEventHandler("UnitCreated", 					"OnPreloadUnitCreated", self)

	self.xmlDoc = XmlDoc.CreateFromFile("Nameplates.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Nameplates:OnPreloadUnitCreated(unitNew)
	self.arPreloadUnits[#self.arPreloadUnits + 1] = unitNew
end

function Nameplates:OnDocumentReady()
	Apollo.RemoveEventHandler("UnitCreated", self)

	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("UnitCreated", 					"OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed", 				"OnUnitDestroyed", self)
	Apollo.RegisterEventHandler("VarChange_FrameCount", 		"OnFrame", self)

	Apollo.RegisterEventHandler("UnitTextBubbleCreate", 		"OnUnitTextBubbleToggled", self)
	Apollo.RegisterEventHandler("UnitTextBubblesDestroyed", 	"OnUnitTextBubbleToggled", self)
	Apollo.RegisterEventHandler("TargetUnitChanged", 			"OnTargetUnitChanged", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 			"OnEnteredCombat", self)
	Apollo.RegisterEventHandler("UnitNameChanged", 				"OnUnitNameChanged", self)
	Apollo.RegisterEventHandler("UnitTitleChanged", 			"OnUnitTitleChanged", self)
	Apollo.RegisterEventHandler("PlayerTitleChange", 			"OnPlayerTitleChanged", self)
	Apollo.RegisterEventHandler("UnitGuildNameplateChanged", 	"OnUnitGuildNameplateChanged",self)
	Apollo.RegisterEventHandler("UnitLevelChanged", 			"OnUnitLevelChanged", self)
	Apollo.RegisterEventHandler("UnitMemberOfGuildChange", 		"OnUnitMemberOfGuildChange", self)
	Apollo.RegisterEventHandler("GuildChange", 					"OnGuildChange", self)
	Apollo.RegisterEventHandler("UnitGibbed",					"OnUnitGibbed", self)
	
	local tRewardUpdateEvents = {
		"QuestObjectiveUpdated", "QuestStateChanged", "ChallengeAbandon", "ChallengeLeftArea",
		"ChallengeFailTime", "ChallengeFailArea", "ChallengeActivate", "ChallengeCompleted",
		"ChallengeFailGeneric", "PublicEventObjectiveUpdate", "PublicEventUnitUpdate",
		"PlayerPathMissionUpdate", "FriendshipAdd", "FriendshipPostRemove", "FriendshipUpdate",
		"PlayerPathRefresh", "ContractObjectiveUpdated", "ContractStateChanged"
	}

	for i, str in pairs(tRewardUpdateEvents) do
		Apollo.RegisterEventHandler(str, "RequestUpdateAllNameplateRewards", self)
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "NameplatesForm", nil, self)

	Apollo.RegisterTimerHandler("VisibilityTimer", "OnVisibilityTimer", self)
	Apollo.CreateTimer("VisibilityTimer", 0.5, true)

	self.wndOptionsMain = Apollo.LoadForm(self.xmlDoc, "StandardModule", self.wndMain:FindChild("ContentMain"), self)
	self.wndOptionsTargeted = Apollo.LoadForm(self.xmlDoc, "TargetedModule", self.wndMain:FindChild("ContentTarget"), self)
	self.wndMain:Show(false)
	self.wndMain:FindChild("ContentMain"):Show(true)
	self.wndMain:FindChild("ContentTarget"):Show(false)
	self.wndMain:FindChild("ContentToggleContainer:NormalViewCheck"):SetCheck(true)

	self.arUnit2Nameplate = {}
	self.arWnd2Nameplate = {}

	for property,tData in pairs(karSavedProperties) do
		if self[property] == nil then
			self[property] = tData.default
		end
		if tData.nControlType == 1 then
			local wndControl = self.wndMain:FindChild(tData.strControlName)
			if wndControl ~= nil then
				wndControl:SetData(property)
			end
		end
	end
	self.bUseOcclusion = Apollo.GetConsoleVariable("ui.occludeNameplatePositions")

	for key, guildCurr in pairs(GuildLib.GetGuilds()) do
		local eGuildType = guildCurr:GetType()
		if eGuildType == GuildLib.GuildType_Guild then
			self.guildDisplayed = guildCurr
		end
		if eGuildType == GuildLib.GuildType_WarParty then
			self.guildWarParty = guildCurr
		end
	end

	-- Cache defaults
	local wndTemp = Apollo.LoadForm(self.xmlDoc, "NameplateNew", nil, self)
	self.nFrameLeft, self.nFrameTop, self.nFrameRight, self.nFrameBottom = wndTemp:FindChild("Container:Health:HealthBars:MaxHealth"):GetAnchorOffsets()
	self.nHealthWidth = self.nFrameRight - self.nFrameLeft
	wndTemp:Destroy()

	self:CreateUnitsFromPreload()
end

function Nameplates:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSave = {}
	for property,tData in pairs(karSavedProperties) do
		tSave[property] = self[property]
	end

	return tSave
end

function Nameplates:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	for property,tData in pairs(karSavedProperties) do
		if tSavedData[property] ~= nil then
			self[property] = tSavedData[property]
		end
	end

	self:CreateUnitsFromPreload()
end

function Nameplates:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("Nameplates_Options")})
end

function Nameplates:CreateUnitsFromPreload()
	if self.bAddonRestoredOrLoaded then
		self.unitPlayer = GameLib.GetPlayerUnit()

		-- Process units created while form was loading
		self.timerPreloadUnitCreateDelay = ApolloTimer.Create(0.5, true, "OnPreloadUnitCreateTimer", self)
		self:OnPreloadUnitCreateTimer()
	end
	self.bAddonRestoredOrLoaded = true
end

function Nameplates:OnPreloadUnitCreateTimer()
	local nCurrentTime = GameLib.GetTickCount()
	
	while #self.arPreloadUnits > 0 do
		local unit = table.remove(self.arPreloadUnits, #self.arPreloadUnits)
		if unit:IsValid() then
			self:OnUnitCreated(unit)
		end
		
		if GameLib.GetTickCount() - nCurrentTime > 250 then
			return
		end
	end
	
	self.timerPreloadUnitCreateDelay:Stop()
	self.arPreloadUnits = nil
	self.timerPreloadUnitCreateDelay = nil
end

function Nameplates:OnVisibilityTimer()
	self:UpdateAllNameplateVisibility()
end

function Nameplates:RequestUpdateAllNameplateRewards()
	self.bRedrawRewardIcons = true
end

function Nameplates:UpdateNameplateRewardInfo(tNameplate)
	local tFlags =
	{
		bVert = false,
		bHideQuests = not self.bShowRewardTypeQuest,
		bHideChallenges = not self.bShowRewardTypeChallenge,
		bHideMissions = not self.bShowRewardTypeMission,
		bHidePublicEvents = not self.bShowRewardTypePublicEvent,
		bHideRivals = not self.bShowRivals,
		bHideFriends = not self.bShowFriends
	}

	if RewardIcons ~= nil and RewardIcons.GetUnitRewardIconsForm ~= nil then
		RewardIcons.GetUnitRewardIconsForm(tNameplate.wnd.questRewards, tNameplate.unitOwner, tFlags)
	end
end

function Nameplates:UpdateAllNameplateVisibility()
	
	for idx, tNameplate in pairs(self.arUnit2Nameplate) do
		self:UpdateNameplateVisibility(tNameplate)
		if self.bRedrawRewardIcons then
			self:UpdateNameplateRewardInfo(tNameplate)
		end
	end

	self.bRedrawRewardIcons = false
end

function Nameplates:UpdateNameplateVisibility(tNameplate)
	local unitOwner = tNameplate.unitOwner
	local wndNameplate = tNameplate.wndNameplate
	local bIsMounted = unitOwner:IsMounted()
	local unitWindow = wndNameplate:GetUnit()

	if bIsMounted and unitWindow == unitOwner then
		if not tNameplate.bMounted then
			wndNameplate:SetUnit(unitOwner:GetUnitMount(), 1)
			tNameplate.bMounted = true
		end
	elseif not bIsMounted and unitWindow ~= unitOwner then
		if tNameplate.bMounted then
			wndNameplate:SetUnit(unitOwner, 1)
			tNameplate.bMounted = false
		end
	end

	local eDisposition = unitOwner:GetDispositionTo(self.unitPlayer)
	local nCon = self:HelperCalculateConValue(unitOwner)
	
	tNameplate.bOnScreen = wndNameplate:IsOnScreen()
	tNameplate.bOccluded = wndNameplate:IsOccluded()
	
	local bNewShow = self:HelperVerifyVisibilityOptions(tNameplate) and self:CheckDrawDistance(tNameplate)
	if bNewShow ~= tNameplate.bShow then
		wndNameplate:Show(bNewShow)
		tNameplate.bShow = bNewShow
	end
	
	if bNewShow then
		-- Disposition based update
		if eDisposition ~= tNameplate.eDisposition then
			tNameplate.wnd.targetMarkerArrow:SetSprite(karDisposition.tTargetSecondary[tNameplate.eDisposition])
			tNameplate.wnd.targetMarker:SetSprite(karDisposition.tTargetPrimary[tNameplate.eDisposition])
		end
		
		local bShowCertainDeath = self.bShowCertainDeathMain
			and (tNameplate.bShowPvpMatch or nCon == #karConColors)
			and tNameplate.eDisposition ~= Unit.CodeEnumDisposition.Friendly
			and unitOwner:GetHealth()
			and unitOwner:ShouldShowNamePlate()
			and not unitOwner:IsDead()
		if bShowCertainDeath ~= tNameplate.wnd.certainDeath:IsShown() then
			tNameplate.wnd.certainDeath:Show(bShowCertainDeath)
		end
		
		-- Does not need to update every frame
		local bShowScaled = unitOwner:IsScaled()
		if bShowScaled ~= tNameplate.wnd.targetScalingMark:IsShown() then
			tNameplate.wnd.targetScalingMark:Show(bShowScaled)
		end
		
		fnColorNameplate(self, tNameplate)
		
		fnDrawHealth(self, tNameplate)
		fnDrawTargeting(self, tNameplate)
		
		fnDrawRewards(self, tNameplate)
	end
	
	tNameplate.eDisposition = eDisposition
	tNameplate.nCon = nCon
end

function Nameplates:OnUnitCreated(unitNew) -- build main options here
	if unitNew == nil
		or not unitNew:IsValid()
		or not unitNew:ShouldShowNamePlate()
		or unitNew:GetType() == "Collectible"
		or unitNew:GetType() == "PinataLoot" then
		-- Never have nameplates
		return
	end

	local idUnit = unitNew:GetId()
	if self.arUnit2Nameplate[idUnit] ~= nil and self.arUnit2Nameplate[idUnit].wndNameplate:IsValid() then
		return
	end

	local wnd = nil
	local wndReferences = nil
	if next(self.arWindowPool) ~= nil then
		local poolEntry = table.remove(self.arWindowPool)
		wnd = poolEntry[1]
		wndReferences = poolEntry[2]
	end

	if wnd == nil or not wnd:IsValid() then
		wnd = Apollo.LoadForm(self.xmlDoc, "NameplateNew", "InWorldHudStratum", self)
		wndReferences = nil
	end

	wnd:Show(false, true)
	wnd:SetUnit(unitNew, 1)

	local strNewUnitType = unitNew:GetType()
	local tNameplate =
	{
		unitOwner 		= unitNew,
		idUnit 			= idUnit,
		wndNameplate	= wnd,
		bOnScreen 		= wnd:IsOnScreen(),
		bOccluded 		= wnd:IsOccluded(),
		bSpeechBubble 	= false,
		bIsTarget 		= GameLib.GetTargetUnit() == unitNew,
		bIsCluster 		= false,
		bIsCasting 		= false,
		bGibbed			= false,
		bIsMounted		= false,
		bShowPvpMatch	= MatchingGame.IsInPVPGame() and (strNewUnitType == "Player" or strNewUnitType == "Esper Pet" or strNewUnitType == "Pet"),
		bIsGuildMember 	= self.guildDisplayed and self.guildDisplayed:IsUnitMember(unitNew) or false,
		bIsWarPartyMember = self.guildWarParty and self.guildWarParty:IsUnitMember(unitNew) or false,
		nVulnerableTime = 0,
		nCon			= self:HelperCalculateConValue(unitOwner),
		eDisposition	= unitNew:GetDispositionTo(self.unitPlayer),
		strUnitType		= strNewUnitType,
		tActivation		= unitNew:GetActivationState(),
		bShow			= false,
		wnd				= wndReferences,
		-- Window visibility
		bShowHealth		= true,
	}

	if wndReferences == nil then
		tNameplate.wnd =
		{
			health = wnd:FindChild("Container:Health"),
			castBar = wnd:FindChild("Container:CastBar"),
			vulnerable = wnd:FindChild("Container:Vulnerable"),
			level = wnd:FindChild("Container:Health:Level"),
			wndGuild = wnd:FindChild("Guild"),
			wndName = wnd:FindChild("NameRewardContainer:Name"),
			certainDeath = wnd:FindChild("TargetAndDeathContainer:CertainDeath"),
			targetScalingMark = wnd:FindChild("TargetScalingMark"),
			nameRewardContainer = wnd:FindChild("NameRewardContainer:RewardContainer"),
			healthMaxShield = wnd:FindChild("Container:Health:HealthBars:MaxShield"),
			healthShieldFill = wnd:FindChild("Container:Health:HealthBars:MaxShield:ShieldFill"),
			healthMaxAbsorb = wnd:FindChild("Container:Health:HealthBars:MaxAbsorb"),
			healthAbsorbFill = wnd:FindChild("Container:Health:HealthBars:MaxAbsorb:AbsorbFill"),
			healthMaxHealth = wnd:FindChild("Container:Health:HealthBars:MaxHealth"),
			healthHealthLabel = wnd:FindChild("Container:Health:HealthLabel"),
			castBarLabel = wnd:FindChild("Container:CastBar:Label"),
			castBarCastFill = wnd:FindChild("Container:CastBar:CastFill"),
			vulnerableVulnFill = wnd:FindChild("Container:Vulnerable:VulnFill"),
			questRewards = wnd:FindChild("NameRewardContainer:RewardContainer:QuestRewards"),
			targetMarkerArrow = wnd:FindChild("TargetAndDeathContainer:TargetMarkerArrow"),
			targetMarker = wnd:FindChild("Container:TargetMarker"),
		}
	end
	
	if tNameplate.bShowPvpMatch then
		tNameplate.wnd.certainDeath:SetSprite(ksprPvpTarget)
	else
		tNameplate.wnd.certainDeath:SetSprite(ksprHighLevel)
	end

	self.arUnit2Nameplate[idUnit] = tNameplate
	self.arWnd2Nameplate[wnd:GetId()] = tNameplate

	self:UpdateNameplateRewardInfo(tNameplate)
	self:DrawName(tNameplate)
	self:DrawGuild(tNameplate)
	self:DrawLevel(tNameplate)
	self:DrawRewards(tNameplate)
	self:DrawTargeting(tNameplate)
	self:DrawHealth(tNameplate)
end

function Nameplates:OnUnitDestroyed(unitOwner)
	local idUnit = unitOwner:GetId()
	if self.arUnit2Nameplate[idUnit] == nil then
		return
	end

	local tNameplate = self.arUnit2Nameplate[idUnit]
	local wndNameplate = tNameplate.wndNameplate

	self.arWnd2Nameplate[wndNameplate:GetId()] = nil
	if #self.arWindowPool < knNameplatePoolLimit then
		wndNameplate:Show(false, true)
		wndNameplate:SetUnit(nil)
		table.insert(self.arWindowPool, {wndNameplate, tNameplate.wnd})
	else
		wndNameplate:Destroy()
	end
	self.arUnit2Nameplate[idUnit] = nil
end

function Nameplates:OnFrame()
	self.unitPlayer = GameLib.GetPlayerUnit()

	local fnHealth = Nameplates.DrawHealthShieldBar
	
	for idx, tNameplate in pairs(self.arUnit2Nameplate) do
		if tNameplate.bShow then
			fnDrawCastBar(self, tNameplate)
			fnDrawVulnerable(self, tNameplate)
			
			if tNameplate.bShowHealth then
				fnHealth(self, tNameplate.wnd.health, tNameplate.unitOwner, tNameplate.eDisposition, tNameplate)
			end
		end
	end
end

function Nameplates:ColorNameplate(tNameplate) -- Every frame
	local unitPlayer = self.unitPlayer
	local unitOwner = tNameplate.unitOwner
	local wndNameplate = tNameplate.wndNameplate

	local eDisposition = tNameplate.eDisposition
	local nCon = self:HelperCalculateConValue(unitOwner)

	local crLevelColorToUse = karConColors[nCon][2]
	if tNameplate.wnd.targetScalingMark:IsShown() then
		crLevelColorToUse = kcrScalingCColor
	elseif unitOwner:GetLevel() == nil then
		crLevelColorToUse = karConColors[1][2]
	end

	local crColorToUse = karDisposition.tTextColors[eDisposition]
	local unitController = unitOwner:GetUnitOwner() or unitOwner
	local strUnitType = unitOwner:GetType()

	if strUnitType == "Player" or strUnitType == "Pet" or strUnitType == "Esper Pet" then
		if eDisposition == Unit.CodeEnumDisposition.Friendly or unitOwner:IsThePlayer() then
			crColorToUse = kcrUnflaggedAlly
			if unitController:IsPvpFlagged() then
				crColorToUse = kcrFlaggedAlly
			elseif unitController:IsInYourGroup() then
				crColorToUse = kcrUnflaggedGroupmate
			elseif tNameplate.bIsGuildMember then
				crColorToUse = kcrUnflaggedGuildmate
			end
		else
			local bIsUnitFlagged = unitController:IsPvpFlagged()
			local bAmIFlagged = GameLib.IsPvpFlagged()

			if not bAmIFlagged and not bIsUnitFlagged then
				crColorToUse = kcrUnflaggedEnemyWhenUnflagged
			elseif bAmIFlagged and not bIsUnitFlagged then
				crColorToUse = kcrUnflaggedEnemyWhenFlagged
			elseif not bAmIFlagged and bIsUnitFlagged then
				crColorToUse = kcrFlaggedEnemyWhenUnflagged
			elseif bAmIFlagged and bIsUnitFlagged then
				crColorToUse = kcrFlaggedEnemyWhenFlagged
			end
		end
	end

	if unitOwner:GetType() ~= "Player" and unitOwner:IsTagged() and not unitOwner:IsTaggedByMe() and not unitOwner:IsSoftKill() then
		crColorToUse = kcrDefaultTaggedColor
	end

	if unitOwner:IsDead() then
		crColorToUse = kcrDeadColor
		crLevelColorToUse = kcrDeadColor
	end

	tNameplate.wnd.level:SetTextColor(crLevelColorToUse)
	tNameplate.wnd.wndName:SetTextColor(crColorToUse)
	tNameplate.wnd.wndGuild:SetTextColor(crColorToUse)
end

function Nameplates:DrawName(tNameplate)
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner

	local wndName = tNameplate.wnd.wndName
	local bUseTarget = tNameplate.bIsTarget
	local bShow = self.bShowNameMain
	if bUseTarget then
		bShow = self.bShowNameTarget
	end

	if wndName:IsShown() ~= bShow then
		wndName:Show(bShow)
	end

	if bShow then
		local strNewName
		if self.bShowTitle then
			strNewName = unitOwner:GetTitleOrName()
		else
			strNewName = unitOwner:GetName()
		end

		if tNameplate.strName ~= strNewName then
			wndName:SetText(strNewName)
			tNameplate.strName = strNewName

			-- Need to consider guild as well for the resize code
			local strNewGuild = unitOwner:GetAffiliationName()
			if unitOwner:GetType() == "Player" and strNewGuild ~= nil and strNewGuild ~= "" then
				strNewGuild = String_GetWeaselString(Apollo.GetString("Nameplates_GuildDisplay"), strNewGuild)
			end

			-- Resize
			local wndNameplate = tNameplate.wndNameplate
			local nLeft, nTop, nRight, nBottom = wndNameplate:GetAnchorOffsets()
			local nHalfNameWidth = math.ceil(math.max(Apollo.GetTextWidth("Nameplates", strNewName), Apollo.GetTextWidth("CRB_Interface9_BO", strNewGuild)) / 2)
			nHalfNameWidth = math.max(nHalfNameWidth, math.ceil(self.nHealthWidth / 2))
			tNameplate.nHalfNameWidth = nHalfNameWidth
			wndNameplate:SetAnchorOffsets(-nHalfNameWidth - 17, nTop, nHalfNameWidth + tNameplate.wnd.nameRewardContainer:ArrangeChildrenHorz(0) + 17, nBottom)
		end
	end
end

function Nameplates:DrawGuild(tNameplate)
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner

	local wndGuild = tNameplate.wnd.wndGuild
	local bUseTarget = tNameplate.bIsTarget
	local bShow = self.bShowTitle
	if bUseTarget then
		bShow = self.bShowGuildNameTarget
	end

	local strNewGuild = unitOwner:GetAffiliationName()
	if unitOwner:GetType() == "Player" and strNewGuild ~= nil and strNewGuild ~= "" then
		strNewGuild = String_GetWeaselString(Apollo.GetString("Nameplates_GuildDisplay"), strNewGuild)
	end

	if bShow and strNewGuild ~= wndGuild:GetText() then
		wndGuild:SetTextRaw(strNewGuild)

		-- Need to consider name as well for the resize code
		local strNewName
		if self.bShowTitle then
			strNewName = unitOwner:GetTitleOrName()
		else
			strNewName = unitOwner:GetName()
		end

		-- Resize
		local nLeft, nTop, nRight, nBottom = wndNameplate:GetAnchorOffsets()
		local nHalfNameWidth = math.ceil(math.max(Apollo.GetTextWidth("Nameplates", strNewName), Apollo.GetTextWidth("CRB_Interface9_BO", strNewGuild)) / 2)
		nHalfNameWidth = math.max(nHalfNameWidth, math.ceil(self.nHealthWidth / 2))
		wndNameplate:SetAnchorOffsets(-nHalfNameWidth - 17, nTop, nHalfNameWidth + tNameplate.wnd.nameRewardContainer:ArrangeChildrenHorz(0) + 17, nBottom)
	end

	wndGuild:Show(bShow and strNewGuild ~= nil and strNewGuild ~= "")
	wndNameplate:ArrangeChildrenVert(2) -- Must be run if bShow is false as well
end

function Nameplates:DrawLevel(tNameplate)
	local unitOwner = tNameplate.unitOwner

	tNameplate.wnd.level:SetText(unitOwner:GetLevel() or "-")
end

function Nameplates:DrawHealth(tNameplate)
	local unitOwner = tNameplate.unitOwner

	local bShow = unitOwner:GetHealth() ~= nil
	
	if unitOwner:GetName() == "Tradeskill XP Comm Call Reward" then
		--Print(tostring(unitOwner:GetHealth()))
	end
	
	if bShow then
		local bUseTarget = tNameplate.bIsTarget
		if bUseTarget then
			bShow = self.bShowHealthTarget
		else
			if self.bShowHealthMain then
				bShow = true
			elseif self.bShowHealthMainDamaged then
				bShow = unitOwner:GetHealth() ~= unitOwner:GetMaxHealth()
			else
				bShow = false
			end
		end
	end
	
	if bShow ~= tNameplate.wnd.health:IsShown() then
		tNameplate.wnd.health:Show(bShow)
		tNameplate.bShowHealth = bShow
	end
end

function Nameplates:DrawCastBar(tNameplate) -- Every frame
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner

	-- Casting; has some onDraw parameters we need to check
	tNameplate.bIsCasting = unitOwner:ShouldShowCastBar()

	local bShowTarget = tNameplate.bIsTarget
	
	local bShow = tNameplate.bIsCasting and self.bShowCastBarMain
	if tNameplate.bIsCasting and bShowTarget then
		bShow = self.bShowCastBarTarget
	end

	local wndCastBar = tNameplate.wnd.castBar
	if bShow ~= wndCastBar:IsShown() then
		wndCastBar:Show(bShow)
	end
	
	if bShow then
		local strCastName = unitOwner:GetCastName()
		if strCastName ~= tNameplate.strCastName then
			tNameplate.wnd.castBarLabel:SetText(strCastName)
			tNameplate.strCastName = strCastName
		end
		
		local nCastDuration = unitOwner:GetCastDuration()
		if nCastDuration ~= tNameplate.nCastDuration then
			tNameplate.wnd.castBarCastFill:SetMax(nCastDuration)
			tNameplate.nCastDuration = nCastDuration
		end
		
		local nCastElapsed = unitOwner:GetCastElapsed()
		if nCastElapsed ~= tNameplate.nCastElapsed then
			tNameplate.wnd.castBarCastFill:SetProgress(nCastElapsed)
			tNameplate.nCastElapsed = nCastElapsed
		end
	end
end

function Nameplates:DrawVulnerable(tNameplate) -- Every frame
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner

	local bUseTarget = tNameplate.bIsTarget
	local wndVulnerable = tNameplate.wnd.vulnerable
	local bShow = false
	
	local nNewVulnerabilityTime = tNameplate.nVulnerabilityTime
	
	if (not bUseTarget and (self.bShowHealthMain or self.bShowHealthMainDamaged)) or (bUseTarget and self.bShowHealthTarget) then
		local nVulnerable = unitOwner:GetCCStateTimeRemaining(Unit.CodeEnumCCState.Vulnerability)
		if nVulnerable == nil then
			bShow = false
		elseif nVulnerable == 0 and nVulnerable ~= tNameplate.nVulnerableTime then
			nNewVulnerabilityTime = 0 -- casting done, set back to 0
			bShow = false
		elseif nVulnerable ~= 0 and nVulnerable < tNameplate.nVulnerableTime then
			tNameplate.wnd.vulnerableVulnFill:SetMax(tNameplate.nVulnerableTime)
			tNameplate.wnd.vulnerableVulnFill:SetProgress(nVulnerable)
			bShow = true
		end
	end
	
	if bShow ~= wndVulnerable:IsShown() then
		wndVulnerable:Show(bShow)
	end
end

function Nameplates:DrawRewards(tNameplate)
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner

	local bUseTarget = tNameplate.bIsTarget
	local bShow = self.bShowRewardsMain
	if bUseTarget then
		bShow = self.bShowRewardsTarget
	end

	if bShow ~= tNameplate.wnd.questRewards:IsShown() then
		tNameplate.wnd.questRewards:Show(bShow)
	end
	
	local tRewardsData = tNameplate.wnd.questRewards:GetData()
	if bShow and tRewardsData ~= nil and tRewardsData.nIcons ~= nil and tRewardsData.nIcons > 0 and tNameplate.nHalfNameWidth ~= nil then
		local wndnameRewardContainer = tNameplate.wnd.nameRewardContainer
		local nLeft, nTop, nRight, nBottom = wndnameRewardContainer:GetAnchorOffsets()
		wndnameRewardContainer:SetAnchorOffsets(tNameplate.nHalfNameWidth, nTop, tNameplate.nHalfNameWidth + wndnameRewardContainer:ArrangeChildrenHorz(0), nBottom)
	end
end

function Nameplates:DrawTargeting(tNameplate)
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner

	local bUseTarget = tNameplate.bIsTarget

	local bShowTargetMarkerArrow = bUseTarget and self.bShowMarkerTarget and not tNameplate.wnd.health:IsShown()

	local bShowTargetMarker = bUseTarget and self.bShowMarkerTarget and tNameplate.wnd.health:IsShown()
	if tNameplate.wnd.targetMarker:IsShown() ~= bShowTargetMarker then
		tNameplate.wnd.targetMarker:Show(bShowTargetMarker)
	end
	if tNameplate.wnd.targetMarkerArrow:IsShown() ~= bShowTargetMarkerArrow then
		tNameplate.wnd.targetMarkerArrow:Show(bShowTargetMarkerArrow, not bShowTargetMarkerArrow)
	end
end

function Nameplates:CheckDrawDistance(tNameplate)
	local unitPlayer = self.unitPlayer
	local unitOwner = tNameplate.unitOwner

	if not unitOwner or not unitPlayer then
	    return false
	end

	local tPosTarget = unitOwner:GetPosition()
	local tPosPlayer = unitPlayer:GetPosition()

	if tPosTarget == nil or tPosPlayer == nil then
		return
	end

	local nDeltaX = tPosTarget.x - tPosPlayer.x
	local nDeltaY = tPosTarget.y - tPosPlayer.y
	local nDeltaZ = tPosTarget.z - tPosPlayer.z

	local nDistance = (nDeltaX * nDeltaX) + (nDeltaY * nDeltaY) + (nDeltaZ * nDeltaZ)

	if tNameplate.bIsTarget or tNameplate.bIsCluster then
		bInRange = nDistance < knTargetRange
		return bInRange
	else
		bInRange = nDistance < self.nMaxRangeSq
		return bInRange
	end
end

function Nameplates:HelperVerifyVisibilityOptions(tNameplate)
	local unitPlayer = self.unitPlayer
	local unitOwner = tNameplate.unitOwner
	
	local bDontShowNameplate = (not unitOwner:ShouldShowNamePlate() and not tNameplate.bIsTarget)
		or ((self.bUseOcclusion and tNameplate.bOccluded) or not tNameplate.bOnScreen)
		or (tNameplate.bGibbed or (tNameplate.bSpeechBubble and not self.bShowDuringSpeech))
	
	if bDontShowNameplate then
		return false
	end
	
	if unitOwner == self.unitPlayer then
		return tNameplate.bIsTarget or (self.bShowMyNameplate and not unitOwner:IsDead())
	end
	
	local eDisposition = tNameplate.eDisposition
	local tActivation = tNameplate.tActivation

	-- if you stare into the abyss the abyss stares back into you
	local bShowNameplate = tNameplate.bIsTarget
		or (not (self.bPlayerInCombat and self.bHideInCombat)
			and ((self.bShowMainObjectiveOnly and tNameplate.bIsObjective)
				or (self.bShowMainGroupOnly and unitOwner:IsInYourGroup())
				or (self.bShowDispositionHostile and eDisposition == Unit.CodeEnumDisposition.Hostile)
				or (self.bShowDispositionNeutral and eDisposition == Unit.CodeEnumDisposition.Neutral)
				or (self.bShowDispositionFriendly and eDisposition == Unit.CodeEnumDisposition.Friendly)
				or (self.bShowDispositionFriendlyPlayer and eDisposition == Unit.CodeEnumDisposition.Friendly and unitOwner:GetType() == "Player")
				or (self.bShowVendor and tActivation.Vendor ~= nil)
				or (self.bShowTaxi and (tActivation.FlightPathSettler ~= nil or tActivation.FlightPath ~= nil or tActivation.FlightPathNew))
				or (self.bShowOrganization and tNameplate.bIsGuildMember)
				or (self.bShowMainObjectiveOnly and ((tActivation.QuestReward ~= nil)
					or (tActivation.QuestNew ~= nil or tActivation.QuestNewMain ~= nil)
					or (tActivation.QuestReceiving ~= nil)
					or (tActivation.TalkTo ~= nil))
				)
			)
		)

	if self.bShowMainObjectiveOnly and not bShowNameplate then
		local tRewardInfo = unitOwner:GetRewardInfo() or {}
		for idx, tReward in pairs(tRewardInfo) do
			if tReward.eType == Unit.CodeEnumRewardInfoType.Quest or tReward.eType == Unit.CodeEnumRewardInfoType.Contract then
				bShowNameplate = true
				break
			end
		end
	end

	return bShowNameplate
end

function Nameplates:DrawHealthShieldBar(wndHealth, unitOwner, eDisposition, tNameplate) -- Every frame
	local nHealthCurr = unitOwner:GetHealth()
	
	if tNameplate.strUnitType == "Simple" or nHealthCurr == nil then
		if nHealthCurr ~= tNameplate.nHealthCurr then
			tNameplate.wnd.healthMaxHealth:SetAnchorOffsets(self.nFrameLeft, self.nFrameTop, self.nFrameRight, self.nFrameBottom)
			tNameplate.wnd.healthHealthLabel:SetText("")
		end
		tNameplate.nHealthCurr = nHealthCurr
		return
	end
	
	local nHealthMax 	= unitOwner:GetMaxHealth()
	local nShieldCurr 	= unitOwner:GetShieldCapacity()
	local nShieldMax 	= unitOwner:GetShieldCapacityMax()
	local nAbsorbCurr 	= 0
	local nAbsorbMax 	= unitOwner:GetAbsorptionMax()
	if nAbsorbMax > 0 then
		nAbsorbCurr = unitOwner:GetAbsorptionValue() -- Since it doesn't clear when the buff drops off
	end
	local nTotalMax = nHealthMax + nShieldMax + nAbsorbMax

	if unitOwner:IsDead() then
		nHealthCurr = 0
	end

	local nHealthTintType = 0
	
	if unitOwner:IsInCCState(Unit.CodeEnumCCState.Vulnerability) then
		nHealthTintType = 3
	elseif nHealthCurr / nHealthMax <= knHealthRed then
		nHealthTintType = 2
	elseif nHealthCurr / nHealthMax <= knHealthYellow then
		nHealthTintType = 1
	end
	
	if nHealthTintType ~= tNameplate.nHealthTintType then
		if nHealthTintType == 3 then
			tNameplate.wnd.healthMaxHealth:SetSprite("CRB_Nameplates:sprNP_PurpleProg")
			tNameplate.wnd.targetMarker:SetSprite("CRB_Nameplates:sprNP_BaseSelectedPurple")
		elseif nHealthTintType == 2 then
			tNameplate.wnd.healthMaxHealth:SetSprite("CRB_Nameplates:sprNP_RedProg")
			tNameplate.wnd.targetMarker:SetSprite("CRB_Nameplates:sprNP_BaseSelectedRed")
		elseif nHealthTintType == 1 then
			tNameplate.wnd.healthMaxHealth:SetSprite("CRB_Nameplates:sprNP_YellowProg")
			tNameplate.wnd.targetMarker:SetSprite("CRB_Nameplates:sprNP_BaseSelectedYellow")
		else
			tNameplate.wnd.healthMaxHealth:SetSprite("CRB_Nameplates:sprNP_GreenProg")
			tNameplate.wnd.targetMarker:SetSprite("CRB_Nameplates:sprNP_BaseSelectedGreen")
		end
		
		tNameplate.nHealthTintType = nHealthTintType
	end
	
	local nPointHealthRight = self.nFrameLeft + (self.nHealthWidth * (nHealthCurr / nTotalMax)) -- applied to the difference between L and R
	local nPointShieldRight = self.nFrameLeft + (self.nHealthWidth * ((nHealthCurr + nShieldMax) / nTotalMax))
	local nPointAbsorbRight = self.nFrameLeft + (self.nHealthWidth * ((nHealthCurr + nShieldMax + nAbsorbMax) / nTotalMax))

	if nShieldMax > 0 and nShieldMax / nTotalMax < 0.2 then
		local nMinShieldSize = 0.2 -- HARDCODE: Minimum shield bar length is 20% of total for formatting
		nPointHealthRight = self.nFrameLeft + (self.nHealthWidth*(math.min(1 - nMinShieldSize, nHealthCurr / nTotalMax)))
		nPointShieldRight = self.nFrameLeft + (self.nHealthWidth*(math.min(1, (nHealthCurr / nTotalMax) + nMinShieldSize)))
	end

	-- Resize
	tNameplate.wnd.healthShieldFill:EnableGlow(nShieldCurr > 0 and nShieldCurr ~= nShieldMax)
	if nShieldCurr ~= tNameplate.nShieldCurr or nShieldMax ~= tNameplate.nShieldMax then
		self:SetBarValue(tNameplate.wnd.healthShieldFill, 0, nShieldCurr, nShieldMax) -- Only the Curr Shield really progress fills
	end
	if nAbsorbCurr ~= tNameplate.nAbsorbCurr or nAbsorbMax ~= tNameplate.nAbsorbMax then
		self:SetBarValue(tNameplate.wnd.healthAbsorbFill, 0, nAbsorbCurr, nAbsorbMax)
	end
	
	local bHealthSizeChanged = nHealthCurr ~= tNameplate.nHealthCurr or nTotalMax ~= tNameplate.nTotalMax
	if bHealthSizeChanged then
		tNameplate.wnd.healthMaxHealth:SetAnchorOffsets(self.nFrameLeft, self.nFrameTop, nPointHealthRight, self.nFrameBottom)
		tNameplate.wnd.healthMaxShield:SetAnchorOffsets(nPointHealthRight - 1, self.nFrameTop, nPointShieldRight, self.nFrameBottom)
		tNameplate.wnd.healthMaxAbsorb:SetAnchorOffsets(nPointShieldRight - 1, self.nFrameTop, nPointAbsorbRight, self.nFrameBottom)
	end

	-- Bars
	local bHasHealth = nHealthCurr > 0
	if bHasHealth ~= tNameplate.wnd.healthShieldFill:IsShown() then
		tNameplate.wnd.healthShieldFill:Show(bHasHealth)
	end
	if bHasHealth ~= tNameplate.wnd.healthMaxHealth:IsShown() then
		tNameplate.wnd.healthMaxHealth:Show(bHasHealth)
	end
	
	local bHasShield = bHasHealth and nShieldMax > 0
	if bHasShield ~= tNameplate.wnd.healthMaxShield:IsShown() then
		tNameplate.wnd.healthMaxShield:Show(bHasShield)
	end
	
	local bHasAbsorb = bHasHealth and nAbsorbMax > 0
	if bHasAbsorb ~= tNameplate.wnd.healthMaxAbsorb:IsShown() then
		tNameplate.wnd.healthMaxAbsorb:Show(bHasAbsorb)
	end

	-- Text
	if nHealthMax ~= tNameplate.nHealthMax or nHealthCurr ~= tNameplate.nHealthCurr or nShieldCurr ~= tNameplate.nShieldCurr then
		local strHealthMax = self:HelperFormatBigNumber(nHealthMax)
		local strHealthCurr = self:HelperFormatBigNumber(nHealthCurr)
		local strShieldCurr = self:HelperFormatBigNumber(nShieldCurr)
	
		local strText = nHealthMax == nHealthCurr and strHealthMax or String_GetWeaselString(Apollo.GetString("TargetFrame_HealthText"), strHealthCurr, strHealthMax)
		if nShieldMax > 0 and nShieldCurr > 0 then
			strText = String_GetWeaselString(Apollo.GetString("TargetFrame_HealthShieldText"), strText, strShieldCurr)
		end
		tNameplate.wnd.healthHealthLabel:SetText(strText)
	end

	tNameplate.nHealthCurr = nHealthCurr
	tNameplate.nHealthMax = nHealthMax
	tNameplate.nShieldCurr = nShieldCurr
	tNameplate.nShieldMax = nShieldMax
	tNameplate.nAbsorbCurr = nAbsorbCurr
	tNameplate.nAbsorbMax = nAbsorbMax
	tNameplate.nTotalMax = nTotalMax
end

function Nameplates:HelperFormatBigNumber(nArg)
	if nArg < 1000 then
		strResult = tostring(nArg)
	elseif nArg < 1000000 then
		if math.floor(nArg%1000/100) == 0 then
			strResult = String_GetWeaselString(Apollo.GetString("TargetFrame_ShortNumberWhole"), math.floor(nArg / 1000))
		else
			strResult = String_GetWeaselString(Apollo.GetString("TargetFrame_ShortNumberFloat"), nArg / 1000)
		end
	elseif nArg < 1000000000 then
		if math.floor(nArg%1000000/100000) == 0 then
			strResult = String_GetWeaselString(Apollo.GetString("TargetFrame_MillionsNumberWhole"), math.floor(nArg / 1000000))
		else
			strResult = String_GetWeaselString(Apollo.GetString("TargetFrame_MillionsNumberFloat"), nArg / 1000000)
		end
	elseif nArg < 1000000000000 then
		if math.floor(nArg%1000000/100000) == 0 then
			strResult = String_GetWeaselString(Apollo.GetString("TargetFrame_BillionsNumberWhole"), math.floor(nArg / 1000000))
		else
			strResult = String_GetWeaselString(Apollo.GetString("TargetFrame_BillionsNumberFloat"), nArg / 1000000)
		end
	else
		strResult = tostring(nArg)
	end
	return strResult
end

function Nameplates:SetBarValue(wndBar, fMin, fValue, fMax)
	wndBar:SetMax(fMax)
	wndBar:SetFloor(fMin)
	wndBar:SetProgress(fValue)
end

function Nameplates:HelperCalculateConValue(unitTarget)
	if unitTarget == nil or not unitTarget:IsValid() or self.unitPlayer == nil or not self.unitPlayer:IsValid() then
		return 1
	end

	local nUnitCon = self.unitPlayer:GetLevelDifferential(unitTarget)

	local nCon = 1 --default setting

	if nUnitCon <= karConColors[1][1] then -- lower bound
		nCon = 1
	elseif nUnitCon >= karConColors[#karConColors][1] then -- upper bound
		nCon = #karConColors
	else
		for idx = 2, (#karConColors - 1) do -- everything in between
			if nUnitCon == karConColors[idx][1] then
				nCon = idx
			end
		end
	end

	return nCon
end

-----------------------------------------------------------------------------------------------
-- Nameplate Events
-----------------------------------------------------------------------------------------------

function Nameplates:OnNameplateNameClick(wndHandler, wndCtrl, eMouseButton)
	local tNameplate = self.arWnd2Nameplate[wndHandler:GetId()]
	if tNameplate == nil then
		return
	end

	local unitOwner = tNameplate.unitOwner
	if GameLib.GetTargetUnit() ~= unitOwner and eMouseButton == GameLib.CodeEnumInputMouse.Left then
		GameLib.SetTargetUnit(unitOwner)
	end
end

function Nameplates:OnWorldLocationOnScreen(wndHandler, wndControl, bOnScreen)
	local tNameplate = self.arWnd2Nameplate[wndHandler:GetId()]
	if tNameplate ~= nil then
		tNameplate.bOnScreen = bOnScreen
		self:UpdateNameplateVisibility(tNameplate)
	end
end

function Nameplates:OnUnitOcclusionChanged(wndHandler, wndControl, bOccluded)
	local tNameplate = self.arWnd2Nameplate[wndHandler:GetId()]
	if tNameplate ~= nil then
		tNameplate.bOccluded = bOccluded
		self:UpdateNameplateVisibility(tNameplate)
	end
end

-----------------------------------------------------------------------------------------------
-- System Events
-----------------------------------------------------------------------------------------------

function Nameplates:OnUnitTextBubbleToggled(tUnitArg, strText, nRange)
	local tNameplate = self.arUnit2Nameplate[tUnitArg:GetId()]
	if tNameplate ~= nil then
		tNameplate.bSpeechBubble = strText ~= nil and strText ~= ""
		self:UpdateNameplateVisibility(tNameplate)
	end
end

function Nameplates:OnEnteredCombat(unitChecked, bInCombat)
	if unitChecked == self.unitPlayer then
		self.bPlayerInCombat = bInCombat
	end
end

function Nameplates:OnUnitGibbed(unitUpdated)
	local tNameplate = self.arUnit2Nameplate[unitUpdated:GetId()]
	if tNameplate ~= nil then
		tNameplate.bGibbed = true
		self:UpdateNameplateVisibility(tNameplate)
	end
end

function Nameplates:OnUnitNameChanged(unitUpdated, strNewName)
	local tNameplate = self.arUnit2Nameplate[unitUpdated:GetId()]
	if tNameplate ~= nil then
		self:DrawName(tNameplate)
	end
end

function Nameplates:OnUnitTitleChanged(unitUpdated)
	local tNameplate = self.arUnit2Nameplate[unitUpdated:GetId()]
	if tNameplate ~= nil then
		self:DrawName(tNameplate)
	end
end

function Nameplates:OnPlayerTitleChanged()
	local tNameplate = self.arUnit2Nameplate[self.unitPlayer:GetId()]
	if tNameplate ~= nil then
		self:DrawName(tNameplate)
	end
end

function Nameplates:OnUnitLevelChanged(unitUpdating)
	local tNameplate = self.arUnit2Nameplate[unitUpdating:GetId()]
	if tNameplate ~= nil then
		self:DrawLevel(tNameplate)
	end
end

function Nameplates:OnGuildChange()
	self.guildDisplayed = nil
	self.guildWarParty = nil
	for key, guildCurr in pairs(GuildLib.GetGuilds()) do
		local eGuildType = guildCurr:GetType()
		if eGuildType == GuildLib.GuildType_Guild then
			self.guildDisplayed = guildCurr
		end
		if eGuildType == GuildLib.GuildType_WarParty then
			self.guildWarParty = guildCurr
		end
	end

	for key, tNameplate in pairs(self.arUnit2Nameplate) do
		local unitOwner = tNameplate.unitOwner
		tNameplate.bIsGuildMember = self.guildDisplayed and self.guildDisplayed:IsUnitMember(unitOwner) or false
		tNameplate.bIsWarPartyMember = self.guildWarParty and self.guildWarParty:IsUnitMember(unitOwner) or false
	end
end

function Nameplates:OnUnitGuildNameplateChanged(unitUpdated)
	local tNameplate = self.arUnit2Nameplate[unitUpdated:GetId()]
	if tNameplate ~= nil then
		self:DrawGuild(tNameplate)
	end
end

function Nameplates:OnUnitMemberOfGuildChange(unitOwner)
	local tNameplate = self.arUnit2Nameplate[unitOwner:GetId()]
	if tNameplate ~= nil then
		self:DrawGuild(tNameplate)
		tNameplate.bIsGuildMember = self.guildDisplayed and self.guildDisplayed:IsUnitMember(unitOwner) or false
		tNameplate.bIsWarPartyMember = self.guildWarParty and self.guildWarParty:IsUnitMember(unitOwner) or false
	end
end

function Nameplates:OnTargetUnitChanged(unitOwner) -- build targeted options here; we get this event when a creature attacks, too
	for idx, tNameplateOther in pairs(self.arUnit2Nameplate) do
		local bIsTarget = tNameplateOther.bIsTarget
		local bIsCluster = tNameplateOther.bIsCluster

		tNameplateOther.bIsTarget = false
		tNameplateOther.bIsCluster = false

		if bIsTarget or bIsCluster then
			self:DrawHealth(tNameplateOther)
			self:DrawName(tNameplateOther)
			self:DrawGuild(tNameplateOther)
			self:DrawLevel(tNameplateOther)
			self:UpdateNameplateRewardInfo(tNameplateOther)
			self:DrawTargeting(tNameplateOther)
		end
	end

	if unitOwner == nil then
		return
	end

	local tNameplate = self.arUnit2Nameplate[unitOwner:GetId()]
	if tNameplate == nil then
		return
	end

	if GameLib.GetTargetUnit() == unitOwner then
		tNameplate.bIsTarget = true
		self:DrawHealth(tNameplate)
		self:DrawName(tNameplate)
		self:DrawGuild(tNameplate)
		self:DrawLevel(tNameplate)
		self:DrawTargeting(tNameplate)
		self:UpdateNameplateRewardInfo(tNameplate)

		local tCluster = unitOwner:GetClusterUnits()
		if tCluster ~= nil then
			tNameplate.bIsCluster = true

			for idx, unitCluster in pairs(tCluster) do
				local tNameplateOther = self.arUnit2Nameplate[unitCluster:GetId()]
				if tNameplateOther ~= nil then
					tNameplateOther.bIsCluster = true
				end
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Options
-----------------------------------------------------------------------------------------------
function Nameplates:OnConfigure()
	self:OnNameplatesOn()
end

function Nameplates:OnNameplatesOn()
	local ePath = PlayerPathLib.GetPlayerPathType()
	self.wndOptionsMain:FindChild("ShowRewardTypeMission"):FindChild("Icon"):SetSprite(karPathSprite[ePath])
	self.wndMain:Show(true)
	self.wndMain:ToFront()
	self:RefreshNameplatesConfigure()
end

function Nameplates:RefreshNameplatesConfigure()
	-- Generic managed controls
	for property,tData in pairs(karSavedProperties) do
		if tData.nControlType == 1 and self[property] ~= nil then
			local wndControl = self.wndMain:FindChild(tData.strControlName)
			if wndControl ~= nil then
				wndControl:SetCheck(self[property])
			end
		end
	end
	--Draw distance
	if self.nMaxRange ~= nil then
		self.wndOptionsMain:FindChild("ShowOptionsBacker:DrawDistanceSlider"):SetValue(self.nMaxRange)
		self.wndOptionsMain:FindChild("ShowOptionsBacker:DrawDistanceLabel"):SetText(String_GetWeaselString(Apollo.GetString("Nameplates_DrawDistance"), self.nMaxRange))
	end
	--Info panel
	if self.bShowHealthMain ~= nil and self.bShowHealthMainDamaged ~= nil then self.wndMain:FindChild("MainShowHealthBarAlways"):SetCheck(self.bShowHealthMain and not self.bShowHealthMainDamaged) end
	if self.bShowHealthMain ~= nil and self.bShowHealthMainDamaged ~= nil then self.wndMain:FindChild("MainShowHealthBarDamaged"):SetCheck(not self.bShowHealthMain and self.bShowHealthMainDamaged) end
	if self.bShowHealthMain ~= nil and self.bShowHealthMainDamaged ~= nil then self.wndMain:FindChild("MainShowHealthBarNever"):SetCheck(not self.bShowHealthMain and not self.bShowHealthMainDamaged) end
	--target components
	if self.bShowMarkerTarget ~= nil then self.wndMain:FindChild("MainHideInCombatOff"):SetCheck(not self.bHideInCombat) end
	--General nameplate occlustion
	self.wndOptionsMain:FindChild("ShowOptionsBacker:MainUseOcclusion"):SetCheck(Apollo.GetConsoleVariable("ui.occludeNameplatePositions"))
end

function Nameplates:OnNormalViewCheck(wndHandler, wndCtrl)
	self.wndMain:FindChild("ContentMain"):Show(true)
	self.wndMain:FindChild("ContentTarget"):Show(false)
end

function Nameplates:OnTargetViewCheck(wndHandler, wndCtrl)
	self.wndMain:FindChild("ContentMain"):Show(false)
	self.wndMain:FindChild("ContentTarget"):Show(true)
end

-- when the OK button is clicked
function Nameplates:OnOK()
	self.wndMain:Show(false) -- hide the window
end

-- when the Cancel button is clicked
function Nameplates:OnCancel()
	self.wndMain:Show(false) -- hide the window
end

function Nameplates:OnDrawDistanceSlider(wndNameplate, wndHandler, nValue, nOldvalue)
	self.wndOptionsMain:FindChild("DrawDistanceLabel"):SetText(String_GetWeaselString(Apollo.GetString("Nameplates_DrawDistance"), nValue))
	self.nMaxRange = nValue-- set new constant, apply math
	self.nMaxRangeSq = nValue * nValue
end

function Nameplates:OnMainShowHealthBarAlways(wndHandler, wndCtrl)
	self:HelperOnMainShowHealthSettingChanged(true, false)
end

function Nameplates:OnMainShowHealthBarDamaged(wndHandler, wndCtrl)
	self:HelperOnMainShowHealthSettingChanged(false, true)
end

function Nameplates:OnMainShowHealthBarNever(wndHandler, wndCtrl)
	self:HelperOnMainShowHealthSettingChanged(false, false)
end

function Nameplates:HelperOnMainShowHealthSettingChanged(bShowHealthMain, bShowHealthMainDamaged)
	self.bShowHealthMain = bShowHealthMain
	self.bShowHealthMainDamaged = bShowHealthMainDamaged
end

function Nameplates:OnMainHideInCombat(wndHandler, wndCtrl)
	self.bHideInCombat = wndCtrl:IsChecked() -- onDraw
end

function Nameplates:OnMainHideInCombatOff(wndHandler, wndCtrl)
	self.bHideInCombat = not wndCtrl:IsChecked() -- onDraw
end

function Nameplates:OnGenericSingleCheck(wndHandler, wndControl, eMouseButton)
	local strSettingName = wndControl:GetData()
	if strSettingName ~= nil then
		self[strSettingName] = wndControl:IsChecked()
		local fnCallback = karSavedProperties[strSettingName].fnCallback
		if fnCallback ~= nil then
			self[fnCallback](self)
		end
	end
end

function Nameplates:OnFriendlyPlayersSingleCheck(wndHandler, wndControl, eMouseButton)
	local strSettingName = wndControl:GetData()
	if strSettingName ~= nil then
		self["bShowDispositionFriendlyPlayer"] = wndControl:IsChecked()
		local fnCallback = karSavedProperties["bShowDispositionFriendlyPlayer"].fnCallback
		if fnCallback ~= nil then
			self[fnCallback](self)
		end
	end
	if not wndControl:IsChecked() then
		if strSettingName ~= nil then
			self["bShowDispositionFriendly"] = false
			local fnCallback = karSavedProperties["bShowDispositionFriendly"].fnCallback
			if fnCallback ~= nil then
				self[fnCallback](self)
			end
		end
	end

	if self.wndOptionsMain:FindChild("MainShowDisposition_FriendlyPlayer"):IsChecked() then
		self.wndOptionsMain:FindChild("MainShowDisposition_3"):Enable(true)
		self.wndOptionsMain:FindChild("MainShowDisposition_3"):SetBGColor("white")
	else
		self.wndOptionsMain:FindChild("MainShowDisposition_3"):Enable(false)
		self.wndOptionsMain:FindChild("MainShowDisposition_3"):SetCheck(false)
		self.wndOptionsMain:FindChild("MainShowDisposition_3"):SetBGColor("UI_AlphaPercent50")
	end
end

function Nameplates:OnSettingNameChanged()
	for idx, tNameplate in pairs(self.arUnit2Nameplate) do
		self:DrawName(tNameplate)
	end
end

function Nameplates:OnSettingTitleChanged()
	for idx, tNameplate in pairs(self.arUnit2Nameplate) do
		self:DrawGuild(tNameplate)
	end
end

function Nameplates:OnSettingHealthChanged()
	for idx, tNameplate in pairs(self.arUnit2Nameplate) do
		self:DrawLevel(tNameplate)
	end
end

function Nameplates:OnOcclusionCheck(wndHandler, wndControl, eMouseButton)
	local bUseOcclusion = wndControl:IsChecked()
	Apollo.SetConsoleVariable("ui.occludeNameplatePositions", bUseOcclusion)
	self.bUseOcclusion = bUseOcclusion
end

-----------------------------------------------------------------------------------------------
-- Local function reference assignments
-----------------------------------------------------------------------------------------------
fnDrawHealth = Nameplates.DrawHealth
fnDrawRewards = Nameplates.DrawRewards
fnDrawCastBar = Nameplates.DrawCastBar
fnDrawVulnerable = Nameplates.DrawVulnerable
fnColorNameplate = Nameplates.ColorNameplate
fnDrawTargeting = Nameplates.DrawTargeting

-----------------------------------------------------------------------------------------------
-- Nameplates Instance
-----------------------------------------------------------------------------------------------
local NameplatesInst = Nameplates:new()
NameplatesInst:Init()
cks="1" Moveable="1" Escapable="1" Overlapped="1" TooltipColor="" Sprite="" IgnoreMouse="1" Tooltip="" TransitionShowHide="1">
        <Control Class="Window" LAnchorPoint="0.5" LAnchorOffset="-116" TAnchorPoint="0" TAnchorOffset="50" RAnchorPo