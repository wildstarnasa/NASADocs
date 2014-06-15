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

-- TODO Delete strings:
-- Nameplates_GuildDisplay

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

local ktHealthBarSprites =
{
	"sprNp_Health_FillGreen",
	"sprNp_Health_FillOrange",
	"sprNp_Health_FillRed"
}

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
	["bShowDispositionFriendlyPlayer"] = { default=false, nControlType=1, strControlName="MainShowDisposition_FriendlyPlayer" },
	["bUseOcclusion"] = { default=true, nControlType=1, strControlName="MainUseOcclusion" },
	--Draw distance
	["nMaxRange"] = { default=70.0, nControlType=0 },
	--Individual
	["bShowNameMain"] = { default=true, nControlType=1, strControlName="IndividualShowName", fnCallback="OnSettingNameChanged" },
	["bShowTitle"] = { default=true, nControlType=1, strControlName="IndividualShowAffiliation", fnCallback="OnSettingTitleChanged" },
	["bShowCertainDeathMain"] = { default=true, nControlType=1, strControlName="IndividualShowCertainDeath" },
	["bShowCastBarMain"] = { default=false, nControlType=1, strControlName="IndividualShowCastBar" },
	["bShowRewardsMain"] = { default=true, nControlType=1, strControlName="IndividualShowRewardIcons", fnCallback="UpdateAllNameplateRewards" },
	--Reward icons
	["bShowRewardTypeQuest"] = { default=true, nControlType=1, strControlName="ShowRewardTypeQuest", fnCallback="UpdateAllNameplateRewards" },
	["bShowRewardTypeMission"] = { default=true, nControlType=1, strControlName="ShowRewardTypeMission", fnCallback="UpdateAllNameplateRewards" },
	["bShowRewardTypeAchievement"] = { default=false, nControlType=1, strControlName="ShowRewardTypeAchievement", fnCallback="UpdateAllNameplateRewards" },
	["bShowRewardTypeChallenge"] = { default=true, nControlType=1, strControlName="ShowRewardTypeChallenge", fnCallback="UpdateAllNameplateRewards" },
	["bShowRewardTypeReputation"] = { default=false, nControlType=1, strControlName="ShowRewardTypeReputation", fnCallback="UpdateAllNameplateRewards" },
	["bShowRewardTypePublicEvent"] = { default=true, nControlType=1, strControlName="ShowRewardTypePublicEvent", fnCallback="UpdateAllNameplateRewards" },
	["bShowRivals"] = { default=true, nControlType=1, strControlName="ShowRewardTypeRival", fnCallback="UpdateAllNameplateRewards" },
	["bShowFriends"] = { default=true, nControlType=1, strControlName="ShowRewardTypeFriend", fnCallback="UpdateAllNameplateRewards" },
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
	
    return o
end

function Nameplates:Init()
    Apollo.RegisterAddon(self, true, nil, {"Tooltips", "RewardIcons"})
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
	self.arPreloadUnits[unitNew:GetId()] = unitNew
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
		"PlayerPathMissionUpdate", "FriendshipAdd", "FriendshipPostRemove", "FriendshipUpdate" 
	}
	
	for i, str in pairs(tRewardUpdateEvents) do
		Apollo.RegisterEventHandler(str, "UpdateAllNameplateRewards", self)
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
		for idUnit, unitNew in pairs(self.arPreloadUnits) do
			self:OnUnitCreated(unitNew)
		end
		self.arPreloadUnits = nil
	end
	self.bAddonRestoredOrLoaded = true
end

function Nameplates:OnVisibilityTimer()
	self:UpdateAllNameplateVisibility()
end

function Nameplates:UpdateAllNameplateRewards()
	for idx, tNameplate in pairs(self.arUnit2Nameplate) do
		self:UpdateNameplateRewardInfo(tNameplate)
	end
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
	end
end

function Nameplates:UpdateNameplateVisibility(tNameplate)
	tNameplate.bOnScreen = tNameplate.wndNameplate:IsOnScreen()
	tNameplate.bOccluded = tNameplate.wndNameplate:IsOccluded()
	tNameplate.eDisposition = tNameplate.unitOwner:GetDispositionTo(self.unitPlayer)
	local bNewShow = self:HelperVerifyVisibilityOptions(tNameplate) and self:CheckDrawDistance(tNameplate)
	if bNewShow ~= tNameplate.bShow then
		tNameplate.wndNameplate:Show(bNewShow)
		tNameplate.bShow = bNewShow
	end
end

function Nameplates:OnUnitCreated(unitNew) -- build main options here
	if not unitNew:ShouldShowNamePlate() 
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
	
	local tNameplate =
	{
		unitOwner 		= unitNew,
		idUnit 			= unitNew:GetId(),
		wndNameplate	= wnd,
		bOnScreen 		= wnd:IsOnScreen(),
		bOccluded 		= wnd:IsOccluded(),
		bSpeechBubble 	= false,
		bIsTarget 		= false,
		bIsCluster 		= false,
		bIsCasting 		= false,
		bGibbed			= false,
		bIsGuildMember 	= self.guildDisplayed and self.guildDisplayed:IsUnitMember(unitNew) or false,
		bIsWarPartyMember = self.guildWarParty and self.guildWarParty:IsUnitMember(unitNew) or false,
		nVulnerableTime = 0,
		eDisposition	= unitNew:GetDispositionTo(self.unitPlayer),
		bShow			= false,
		wnd				= wndReferences,
	}
	
	if wndReferences == nil then
		tNameplate.wnd =
		{
			health = wnd:FindChild("Container:Health"),
			castBar = wnd:FindChild("Container:CastBar"),
			vulnerable = wnd:FindChild("Container:Vulnerable"),
			level = wnd:FindChild("Container:Health:Level"),
			guild = wnd:FindChild("Guild"),
			name = wnd:FindChild("NameRewardContainer:Name"),
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
	
	self.arUnit2Nameplate[idUnit] = tNameplate
	self.arWnd2Nameplate[wnd:GetId()] = tNameplate
	
	self:DrawName(tNameplate)
	self:DrawGuild(tNameplate)
	self:DrawLevel(tNameplate)
	self:UpdateNameplateRewardInfo(tNameplate)
	self:DrawRewards(tNameplate)
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
	
	for idx, tNameplate in pairs(self.arUnit2Nameplate) do
		self:DrawNameplate(tNameplate)
	end
end

function Nameplates:DrawNameplate(tNameplate)
	if not tNameplate.bShow then
		return
	end
	
	local unitPlayer = self.unitPlayer
	local unitOwner = tNameplate.unitOwner
	local wndNameplate = tNameplate.wndNameplate
	
	if unitOwner:IsMounted() and wndNameplate:GetUnit() == unitOwner then
		wndNameplate:SetUnit(unitOwner:GetUnitMount(), 1)
	elseif not unitOwner:IsMounted() and wndNameplate:GetUnit() ~= unitOwner then
		wndNameplate:SetUnit(unitOwner, 1)
	end
	
	self:DrawHealth(tNameplate)
	
	local nCon = self:HelperCalculateConValue(unitOwner)
	tNameplate.wnd.certainDeath:Show(self.bShowCertainDeathMain and nCon == #karConColors and tNameplate.eDisposition ~= Unit.CodeEnumDisposition.Friendly and unitOwner:GetHealth() and unitOwner:ShouldShowNamePlate() and not unitOwner:IsDead())
	tNameplate.wnd.targetScalingMark:Show(unitOwner:IsScaled())
	
	self:DrawRewards(tNameplate)
	self:DrawCastBar(tNameplate)
	self:DrawVulnerable(tNameplate)
	
	self:ColorNameplate(tNameplate)
end

function Nameplates:ColorNameplate(tNameplate)
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
	tNameplate.wnd.name:SetTextColor(crColorToUse)
	tNameplate.wnd.guild:SetTextColor(crColorToUse)
end

function Nameplates:DrawName(tNameplate)
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner

	local wndName = tNameplate.wnd.name
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
		
		if wndName:GetText() ~= strNewName then
			local wndNameRewardContainer = tNameplate.wnd.nameRewardContainer
			local nNameWidth = Apollo.GetTextWidth("Nameplates", strNewName)
			local nHalfNameWidth = math.ceil(nNameWidth / 2)
			
			-- Rewards also depend on name
			local nLeft, nTop, nRight, nBottom = wndNameRewardContainer:GetAnchorOffsets()
			wndNameRewardContainer:SetAnchorOffsets(nHalfNameWidth, nTop, nHalfNameWidth + wndNameRewardContainer:ArrangeChildrenHorz(0), nBottom)
			
			-- Resize Name
			nLeft, nTop, nRight, nBottom = wndName:GetAnchorOffsets()
			wndName:SetAnchorOffsets(-nHalfNameWidth - 15, nTop, nHalfNameWidth + 15, nBottom)
			wndName:SetText(strNewName)
		end
		
		
	end
end

function Nameplates:DrawGuild(tNameplate)
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner
	
	local wndGuild = tNameplate.wnd.guild
	local bUseTarget = tNameplate.bIsTarget
	local bShow = self.bShowTitle
	if bUseTarget then
		bShow = self.bShowGuildNameTarget
	end
	
	local strNewGuild = unitOwner:GetAffiliationName()
	if unitOwner:GetType() == "Player" and strNewGuild ~= nil and strNewGuild ~= "" then
		strNewGuild = String_GetWeaselString(Apollo.GetString("Nameplates_GuildDisplay"), strNewGuild)
	end
	
	if strNewGuild ~= wndGuild:GetText() then
		wndGuild:SetTextRaw(strNewGuild)
	end
	
	local bShow = bShow and strNewGuild ~= nil and strNewGuild ~= ""
	
	if wndGuild:IsShown() ~= bShow then
		wndGuild:Show(bShow)
		wndNameplate:ArrangeChildrenVert(2)
	end
end

function Nameplates:DrawLevel(tNameplate)
	local unitOwner = tNameplate.unitOwner
	
	tNameplate.wnd.level:SetText(unitOwner:GetLevel() or "-")
end

function Nameplates:DrawHealth(tNameplate)
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner

	local wndHealth = tNameplate.wnd.health
	
	if unitOwner:GetHealth() == nil then
		wndHealth:Show(false)
		return
	end
	
	local bUseTarget = tNameplate.bIsTarget
	if bUseTarget then
		wndHealth:Show(self.bShowHealthTarget)
	else
		if self.bShowHealthMain then
			wndHealth:Show(true)
		elseif self.bShowHealthMainDamaged then
			wndHealth:Show(unitOwner:GetHealth() ~= unitOwner:GetMaxHealth())
		else
			wndHealth:Show(false)
		end
	end
	if wndHealth:IsShown() then
		self:HelperDoHealthShieldBar(wndHealth, unitOwner, tNameplate.eDisposition, tNameplate)
	end
end

function Nameplates:DrawCastBar(tNameplate)
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner
	
	-- Casting; has some onDraw parameters we need to check
	tNameplate.bIsCasting = unitOwner:ShouldShowCastBar()
	
	local bShowTarget = tNameplate.bIsTarget
	local wndCastBar = tNameplate.wnd.castBar
	local bShow = tNameplate.bIsCasting and self.bShowCastBarMain
	if tNameplate.bIsCasting and bShowTarget then
		bShow = self.bShowCastBarTarget
	end
	
	wndCastBar:Show(bShow)
	if bShow then
		tNameplate.wnd.castBarLabel:SetText(unitOwner:GetCastName())
		tNameplate.wnd.castBarCastFill:SetMax(unitOwner:GetCastDuration())
		tNameplate.wnd.castBarCastFill:SetProgress(unitOwner:GetCastElapsed())
	end
end

function Nameplates:DrawVulnerable(tNameplate)
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner
	
	local bUseTarget = tNameplate.bIsTarget
	local wndVulnerable = tNameplate.wnd.vulnerable
	
	local bIsVulnerable = false
	if (not bUseTarget and (self.bShowHealthMain or self.bShowHealthMainDamaged)) or (bUseTarget and self.bShowHealthTarget) then
		local nVulnerable = unitOwner:GetCCStateTimeRemaining(Unit.CodeEnumCCState.Vulnerability)
		if nVulnerable == nil then
			wndVulnerable:Show(false)
		elseif nVulnerable == 0 and nVulnerable ~= tNameplate.nVulnerableTime then
			tNameplate.nVulnerableTime = 0 -- casting done, set back to 0
			wndVulnerable:Show(false)
		elseif nVulnerable ~= 0 and nVulnerable > tNameplate.nVulnerableTime then
			tNameplate.nVulnerableTime = nVulnerable
			wndVulnerable:Show(true)
			bIsVulnerable = true
		elseif nVulnerable ~= 0 and nVulnerable < tNameplate.nVulnerableTime then
			tNameplate.wnd.vulnerableVulnFill:SetMax(tNameplate.nVulnerableTime)
			tNameplate.wnd.vulnerableVulnFill:SetProgress(nVulnerable)
			bIsVulnerable = true
		end
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
	
	tNameplate.wnd.questRewards:Show(bShow)
	local tRewardsData = tNameplate.wnd.questRewards:GetData()
	if bShow and tRewardsData ~= nil and tRewardsData.nIcons ~= nil and tRewardsData.nIcons > 0 then
		local strName = tNameplate.wnd.name:GetText()
		local nNameWidth = Apollo.GetTextWidth("CRB_Interface9_BBO", strName)
		local nHalfNameWidth = nNameWidth / 2
		
		local wndnameRewardContainer = tNameplate.wnd.nameRewardContainer
		local nLeft, nTop, nRight, nBottom = wndnameRewardContainer:GetAnchorOffsets()
		wndnameRewardContainer:SetAnchorOffsets(nHalfNameWidth, nTop, nHalfNameWidth + wndnameRewardContainer:ArrangeChildrenHorz(0), nBottom)
	end
end

function Nameplates:DrawTargeting(tNameplates)
	local wndNameplate = tNameplate.wndNameplate
	local unitOwner = tNameplate.unitOwner

	local bUseTarget = tNameplate.bIsTarget
	
	local bShowTargetMarkerArrow = bUseTarget and self.bShowMarkerTarget and not tNameplates.wnd.health:IsShown()
	tNameplate.wnd.targetMarkerArrow:SetSprite(karDisposition.tTargetSecondary[tNameplate.eDisposition])
	tNameplate.wnd.targetMarker:SetSprite(karDisposition.tTargetPrimary[tNameplate.eDisposition])

	if tNameplate.nVulnerableTime > 0 then
		tNameplate.wnd.targetMarker:SetSprite("sprNP_BaseSelectedPurple")
	end

	tNameplate.wnd.targetMarker:Show(bUseTarget and self.bShowMarkerTarget)
	tNameplate.wnd.targetMarkerArrow:Show(bShowTargetMarkerArrow, not bShowTargetMarkerArrow)
end

function Nameplates:CheckDrawDistance(tNameplate)
	local unitPlayer = self.unitPlayer
	local unitOwner = tNameplate.unitOwner
	
	if not unitOwner or not unitPlayer then
	    return false
	end

	tPosTarget = unitOwner:GetPosition()
	tPosPlayer = unitPlayer:GetPosition()

	if tPosTarget == nil then
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
		bInRange = nDistance < (self.nMaxRange * self.nMaxRange) -- squaring for quick maths
		return bInRange
	end
end

function Nameplates:HelperVerifyVisibilityOptions(tNameplate)
	local unitPlayer = self.unitPlayer
	local unitOwner = tNameplate.unitOwner
	local eDisposition = tNameplate.eDisposition
	
	local bHiddenUnit = not unitOwner:ShouldShowNamePlate()
	if bHiddenUnit and not tNameplate.bIsTarget then
		return false
	end
	
	if (self.bUseOcclusion and tNameplate.bOccluded) or not tNameplate.bOnScreen then
		return false
	end
	
	if tNameplate.bGibbed or tNameplate.bSpeechBubble then
		return false
	end
	
	local bShowNameplate = false
	
	if self.bShowMainObjectiveOnly and tNameplate.bIsObjective then
		bShowNameplate = true
	end

	if self.bShowMainGroupOnly and unitOwner:IsInYourGroup() then
		bShowNameplate = true
	end

	if self.bShowDispositionHostile and eDisposition == Unit.CodeEnumDisposition.Hostile then
		bShowNameplate = true
	end
	
	if self.bShowDispositionNeutral and eDisposition == Unit.CodeEnumDisposition.Neutral then
		bShowNameplate = true
	end
	
	if self.bShowDispositionFriendly and eDisposition == Unit.CodeEnumDisposition.Friendly then
		bShowNameplate = true
	end
	
	if self.bShowDispositionFriendlyPlayer and eDisposition == Unit.CodeEnumDisposition.Friendly and unitOwner:GetType() == "Player" then
		bShowNameplate = true
	end

	local tActivation = unitOwner:GetActivationState()
	
	if self.bShowVendor and tActivation.Vendor ~= nil then
		bShowNameplate = true
	end
	
	if self.bShowTaxi and (tActivation.FlightPathSettler ~= nil or tActivation.FlightPath ~= nil or tActivation.FlightPathNew) then
		bShowNameplate = true
	end
	
	if self.bShowOrganization and tNameplate.bIsGuildMember then
		bShowNameplate = true
	end

	if self.bShowMainObjectiveOnly then
		-- QuestGivers too
		if tActivation.QuestReward ~= nil then
			bShowNameplate = true
		end
		
		if tActivation.QuestNew ~= nil or tActivation.QuestNewMain ~= nil then
			bShowNameplate = true
		end
		
		if tActivation.QuestReceiving ~= nil then
			bShowNameplate = true
		end
		
		if tActivation.TalkTo ~= nil then
			bShowNameplate = true
		end
	end

	if bShowNameplate then
		bShowNameplate = not (self.bPlayerInCombat and self.bHideInCombat)
	end
	
	if unitOwner:IsThePlayer() then
		if self.bShowMyNameplate and not unitOwner:IsDead() then
			bShowNameplate = true
		else
			bShowNameplate = false
		end
	end

	return bShowNameplate or tNameplate.bIsTarget
end

function Nameplates:HelperDoHealthShieldBar(wndHealth, unitOwner, eDisposition, tNameplate)
	local nVulnerabilityTime = unitOwner:GetCCStateTimeRemaining(Unit.CodeEnumCCState.Vulnerability)

	if unitOwner:GetType() == "Simple" or unitOwner:GetHealth() == nil then
		tNameplate.wnd.healthMaxHealth:SetAnchorOffsets(self.nFrameLeft, self.nFrameTop, self.nFrameRight, self.nFrameBottom)
		tNameplate.wnd.healthHealthLabel:SetText("")
		return
	end

	local nHealthCurr 	= unitOwner:GetHealth()
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
	
	-- Scaling
	--[[local nPointHealthRight = self.nFrameR * (nHealthCurr / nTotalMax) -
	local nPointShieldRight = self.nFrameR * ((nHealthCurr + nShieldMax) / nTotalMax)
	local nPointAbsorbRight = self.nFrameR * ((nHealthCurr + nShieldMax + nAbsorbMax) / nTotalMax)--]]

	local nPointHealthRight = self.nFrameLeft + (self.nHealthWidth * (nHealthCurr / nTotalMax)) -- applied to the difference between L and R
	local nPointShieldRight = self.nFrameLeft + (self.nHealthWidth * ((nHealthCurr + nShieldMax) / nTotalMax))
	local nPointAbsorbRight = self.nFrameLeft + (self.nHealthWidth * ((nHealthCurr + nShieldMax + nAbsorbMax) / nTotalMax))


	if nShieldMax > 0 and nShieldMax / nTotalMax < 0.2 then
		local nMinShieldSize = 0.2 -- HARDCODE: Minimum shield bar length is 20% of total for formatting
		--nPointHealthRight = self.nFrameR * math.min(1-nMinShieldSize, nHealthCurr / nTotalMax) -- Health is normal, but caps at 80%
		--nPointShieldRight = self.nFrameR * math.min(1, (nHealthCurr / nTotalMax) + nMinShieldSize) -- If not 1, the size is thus healthbar + hard minimum

		nPointHealthRight = self.nFrameLeft + (self.nHealthWidth*(math.min(1 - nMinShieldSize, nHealthCurr / nTotalMax)))
		nPointShieldRight = self.nFrameLeft + (self.nHealthWidth*(math.min(1, (nHealthCurr / nTotalMax) + nMinShieldSize)))
	end

	-- Resize
	tNameplate.wnd.healthShieldFill:EnableGlow(nShieldCurr > 0 and nShieldCurr ~= nShieldMax)
	self:SetBarValue(tNameplate.wnd.healthShieldFill, 0, nShieldCurr, nShieldMax) -- Only the Curr Shield really progress fills
	self:SetBarValue(tNameplate.wnd.healthAbsorbFill, 0, nAbsorbCurr, nAbsorbMax)
	tNameplate.wnd.healthMaxHealth:SetAnchorOffsets(self.nFrameLeft, self.nFrameTop, nPointHealthRight, self.nFrameBottom)
	tNameplate.wnd.healthMaxShield:SetAnchorOffsets(nPointHealthRight - 1, self.nFrameTop, nPointShieldRight, self.nFrameBottom)
	tNameplate.wnd.healthMaxAbsorb:SetAnchorOffsets(nPointShieldRight - 1, self.nFrameTop, nPointAbsorbRight, self.nFrameBottom)

	-- Bars
	tNameplate.wnd.healthShieldFill:Show(nHealthCurr > 0)
	tNameplate.wnd.healthMaxHealth:Show(nHealthCurr > 0)
	tNameplate.wnd.healthMaxShield:Show(nHealthCurr > 0 and nShieldMax > 0)
	tNameplate.wnd.healthMaxAbsorb:Show(nHealthCurr > 0 and nAbsorbMax > 0)

	-- Text
	local strHealthMax = self:HelperFormatBigNumber(nHealthMax)
	local strHealthCurr = self:HelperFormatBigNumber(nHealthCurr)
	local strShieldCurr = self:HelperFormatBigNumber(nShieldCurr)

	local strText = nHealthMax == nHealthCurr and strHealthMax or String_GetWeaselString(Apollo.GetString("TargetFrame_HealthText"), strHealthCurr, strHealthMax)
	if nShieldMax > 0 and nShieldCurr > 0 then
		strText = String_GetWeaselString(Apollo.GetString("TargetFrame_HealthShieldText"), strText, strShieldCurr)
	end
	tNameplate.wnd.healthHealthLabel:SetText(strText)

	-- Sprite
	if nVulnerabilityTime and nVulnerabilityTime > 0 then
		tNameplate.wnd.healthMaxHealth:SetSprite("CRB_Nameplates:sprNP_PurpleProg")
	else
		tNameplate.wnd.healthMaxHealth:SetSprite(karDisposition.tHealthBar[eDisposition])
	end

	--[[
	elseif nHealthCurr / nHealthMax < .3 then
		wndHealth:FindChild("MaxHealth"):SetSprite(ktHealthBarSprites[3])
	elseif 	nHealthCurr / nHealthMax < .5 then
		wndHealth:FindChild("MaxHealth"):SetSprite(ktHealthBarSprites[2])
	else
		wndHealth:FindChild("MaxHealth"):SetSprite(ktHealthBarSprites[1])
	end]]--
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
	if unitTarget == nil or self.unitPlayer == nil then
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
			self:DrawName(tNameplateOther)
			self:DrawGuild(tNameplateOther)
			self:DrawLevel(tNameplateOther)
			self:UpdateNameplateRewardInfo(tNameplateOther)
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
		self:DrawName(tNameplate)
		self:DrawGuild(tNameplate)
		self:DrawLevel(tNameplate)
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
	self:RefreshNameplatesConfigure()
end

function Nameplates:RefreshNameplatesConfigure()
	-- Generic maanged controls
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
	if self.bHideInCombat ~= nil then self.wndMain:FindChild("MainHideInCombat"):SetCheck(self.bHideInCombat) end
	if self.bShowMarkerTarget ~= nil then self.wndMain:FindChild("MainHideInCombatOff"):SetCheck(not self.bHideInCombat) end
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

-----------------------------------------------------------------------------------------------
-- Nameplates Instance
-----------------------------------------------------------------------------------------------
local NameplatesInst = Nameplates:new()
NameplatesInst:Init()
