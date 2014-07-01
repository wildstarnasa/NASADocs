require "Window"
require "Unit"
require "GameLib"
require "Apollo"
require "PathMission"
require "P2PTrading"

local TargetFrame = {}
local UnitFrames = {}

local knMaxLevel							= 50
local knIconicArchetype						= 23
local knFrameWidthMax	 					= 400
local knFrameWidthShield	 				= 372
local knFrameWidthMin	 					= 340
local knClusterFrameWidth 					= 60 -- MUST MATCH XML
local knClusterFrameHeight 					= 62 -- MUST MATCH XML
local knClusterFrameVertOffset 				= 120 -- how far down to move the cluster members
local knHealthRed							= 0.3
local knHealthYellow						= 0.5
local knWindowStayOnScreenWidthOffset 		= 200
local knWindowStayOnScreenHeightOffset 		= 200

local kstrScalingHex = "ffffbf80"
local kcrScalingCColor = CColor.new(1.0, 191/255, 128/255, 0.7)

local karDispositionColors =
{
	[Unit.CodeEnumDisposition.Neutral]  = ApolloColor.new("DispositionNeutral"),
	[Unit.CodeEnumDisposition.Hostile]  = ApolloColor.new("DispositionHostile"),
	[Unit.CodeEnumDisposition.Friendly] = ApolloColor.new("DispositionFriendly"),
}

local ktDispositionToTTooltip =
{
	[Unit.CodeEnumDisposition.Neutral]  = Apollo.GetString("TargetFrame_NeutralTooltip"),
	[Unit.CodeEnumDisposition.Hostile]  = Apollo.GetString("TargetFrame_HostileTooltip"),
	[Unit.CodeEnumDisposition.Friendly] = Apollo.GetString("TargetFrame_FriendlyTooltip"),
}

local kstrRaidMarkerToSprite =
{
	"Icon_Windows_UI_CRB_Marker_Bomb",
	"Icon_Windows_UI_CRB_Marker_Ghost",
	"Icon_Windows_UI_CRB_Marker_Mask",
	"Icon_Windows_UI_CRB_Marker_Octopus",
	"Icon_Windows_UI_CRB_Marker_Pig",
	"Icon_Windows_UI_CRB_Marker_Chicken",
	"Icon_Windows_UI_CRB_Marker_Toaster",
	"Icon_Windows_UI_CRB_Marker_UFO",
}

local karFactionToString = --Used for the Attachment Frame Sprites
{
	[Unit.CodeEnumFaction.ExilesPlayer]		= "Exile",
	[171]									= "Exile", --Exile NPC's
	
	[Unit.CodeEnumFaction.DominionPlayer]	= "Dominion",
	[170]									= "Dominion", --Dominion NPC's
}

-- Todo: break these out onto options
local kcrGroupTextColor					= ApolloColor.new("crayBlizzardBlue")
local kcrFlaggedFriendlyTextColor 		= karDispositionColors[Unit.CodeEnumDisposition.Friendly]
local kcrDefaultGuildmemberTextColor 	= karDispositionColors[Unit.CodeEnumDisposition.Friendly]
local kcrHostileEnemyTextColor 			= karDispositionColors[Unit.CodeEnumDisposition.Hostile]
local kcrAggressiveEnemyTextColor 		= karDispositionColors[Unit.CodeEnumDisposition.Neutral]
local kcrNeutralEnemyTextColor 			= ApolloColor.new("crayDenim")
local kcrDefaultUnflaggedAllyTextColor 	= karDispositionColors[Unit.CodeEnumDisposition.Friendly]

-- TODO:Localize all of these
-- differential value, color, title, description, title color (for tooltip)
local karConInfo =
{
	{-4, ApolloColor.new("ConTrivial"), 	Apollo.GetString("TargetFrame_Trivial"), 	Apollo.GetString("TargetFrame_NoXP"), 				"ff7d7d7d"},
	{-3, ApolloColor.new("ConInferior"), 	Apollo.GetString("TargetFrame_Inferior"), 	Apollo.GetString("TargetFrame_VeryReducedXP"), 		"ff01ff07"},
	{-2, ApolloColor.new("ConMinor"), 		Apollo.GetString("TargetFrame_Minor"), 		Apollo.GetString("TargetFrame_ReducedXP"), 			"ff01fcff"},
	{-1, ApolloColor.new("ConEasy"), 		Apollo.GetString("TargetFrame_Easy"), 		Apollo.GetString("TargetFrame_SlightlyReducedXP"), 	"ff597cff"},
	{ 0, ApolloColor.new("ConAverage"), 	Apollo.GetString("TargetFrame_Average"), 	Apollo.GetString("TargetFrame_StandardXP"), 		"ffffffff"},
	{ 1, ApolloColor.new("ConModerate"), 	Apollo.GetString("TargetFrame_Moderate"), 	Apollo.GetString("TargetFrame_SlightlyMoreXP"), 	"ffffff00"},
	{ 2, ApolloColor.new("ConTough"), 		Apollo.GetString("TargetFrame_Tough"), 		Apollo.GetString("TargetFrame_IncreasedXP"), 		"ffff8000"},
	{ 3, ApolloColor.new("ConHard"), 		Apollo.GetString("TargetFrame_Hard"), 		Apollo.GetString("TargetFrame_HighlyIncreasedXP"), 	"ffff0000"},
	{ 4, ApolloColor.new("ConImpossible"), 	Apollo.GetString("TargetFrame_Impossible"), Apollo.GetString("TargetFrame_GreatlyIncreasedXP"),	"ffff00ff"}
}

-- Todo: Localize
local ktRankDescriptions =
{
	[Unit.CodeEnumRank.Fodder] 		= 	{Apollo.GetString("TargetFrame_Fodder"), 		Apollo.GetString("TargetFrame_VeryWeak")},
	[Unit.CodeEnumRank.Minion] 		= 	{Apollo.GetString("TargetFrame_Minion"), 		Apollo.GetString("TargetFrame_Weak")},
	[Unit.CodeEnumRank.Standard]	= 	{Apollo.GetString("TargetFrame_Grunt"), 		Apollo.GetString("TargetFrame_EasyAppend")},
	[Unit.CodeEnumRank.Champion] 	=	{Apollo.GetString("TargetFrame_Challenger"), 	Apollo.GetString("TargetFrame_AlmostEqual")},
	[Unit.CodeEnumRank.Superior] 	=  	{Apollo.GetString("TargetFrame_Superior"), 		Apollo.GetString("TargetFrame_Strong")},
	[Unit.CodeEnumRank.Elite] 		= 	{Apollo.GetString("TargetFrame_Prime"), 		Apollo.GetString("TargetFrame_VeryStrong")},
}

local karClassToIcon =
{
	[GameLib.CodeEnumClass.Warrior] 		= "IconSprites:Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "IconSprites:Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Esper] 			= "IconSprites:Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "IconSprites:Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "IconSprites:Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Spellslinger] 	= "IconSprites:Icon_Windows_UI_CRB_Spellslinger",
}

local kstrTooltipBodyColor = "ffc0c0c0"
local kstrTooltipTitleColor = "ffdadada"

local kstrFriendSprite 			= "ClientSprites:Icon_Windows_UI_CRB_Friend"
local kstrAccountFriendSprite 	= "ClientSprites:Icon_Windows_UI_CRB_Friend"
local kstrRivalSprite 			= "ClientSprites:Icon_Windows_UI_CRB_Rival"

function UnitFrames:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

function UnitFrames:Init()
	Apollo.RegisterAddon(self)
end

function UnitFrames:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("TargetFrame.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function UnitFrames:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterSlashCommand("focus", "OnFocusSlashCommand", self)
	
	Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterLoaded", self)
	Apollo.RegisterEventHandler("TargetUnitChanged", "OnTargetUnitChanged", self)
	Apollo.RegisterEventHandler("AlternateTargetUnitChanged", "OnAlternateTargetUnitChanged", self)
	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)
	
	self.luaUnitFrame = TargetFrame:new()
	self.luaTargetFrame = TargetFrame:new()
	self.luaFocusFrame = TargetFrame:new()
	
	self.luaFocusFrame:Init(self, 	{fScale=1.0, nConsoleVar="hud.focusTargetFrameDisplay", bDrawClusters=false})
	self.luaTargetFrame:Init(self, 	{fScale=1.0, bFlipped=true})
	self.luaUnitFrame:Init(self, 	{fScale=1.0, nConsoleVar="hud.myUnitFrameDisplay", bDrawToT=false})
	
	-- setup default positions
	self.luaUnitFrame.locDefaultPosition = WindowLocation.new({fPoints = {0.25, 1, 0.25, 1}, nOffsets = {0,-324,400,-220}})
	self.luaTargetFrame.locDefaultPosition = WindowLocation.new({fPoints = {0.75, 1, 0.75, 1}, nOffsets = {-400,-324,0,-220}})
	self.luaFocusFrame.locDefaultPosition = WindowLocation.new({fPoints = {0, 1, 0, 1}, nOffsets = {30,-454,430,-350}})	
	
	self.luaUnitFrame:SetPosition(self.luaUnitFrame.locDefaultPosition)
	self.luaTargetFrame:SetPosition(self.luaTargetFrame.locDefaultPosition)
	self.luaFocusFrame:SetPosition(self.luaFocusFrame.locDefaultPosition)
	
	if GameLib.GetPlayerUnit() ~= nil then
		self:OnCharacterLoaded()	
	end
end

function UnitFrames:OnFrame()
	self:OnCharacterLoaded()
end

function UnitFrames:OnCharacterLoaded()
	local unitPlayer = GameLib.GetPlayerUnit()
	
	if unitPlayer ~= nil then
		local unitTarget = unitPlayer:GetTarget()
		local altPlayerTarget = unitPlayer:GetAlternateTarget()
	
		self.luaUnitFrame:SetTarget(unitPlayer)
		self.luaTargetFrame:SetTarget(unitTarget)
		self.luaFocusFrame:SetTarget(altPlayerTarget)
	end
end

function UnitFrames:OnTargetUnitChanged(unitTarget)
	self.luaTargetFrame:SetTarget(unitTarget)
end

function UnitFrames:OnAlternateTargetUnitChanged(unitTarget)
	self.luaFocusFrame:SetTarget(unitTarget)
end

function UnitFrames:OnFocusSlashCommand()
	local unitTarget = GameLib.GetTargetUnit()
	
	GameLib.GetPlayerUnit():SetAlternateTarget(unitTarget)
end

function UnitFrames:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.luaUnitFrame.wndMainClusterFrame,		strName = Apollo.GetString("OptionsHUD_MyUnitFrameLabel")})
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.luaTargetFrame.wndMainClusterFrame,	strName = Apollo.GetString("OptionsHUD_TargetFrameLabel")})
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.luaFocusFrame.wndMainClusterFrame,	strName = Apollo.GetString("OptionsHUD_FocusTargetLabel")})
end

function TargetFrame:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function TargetFrame:Init(luaUnitFrameSystem, tParams)
	Apollo.LinkAddon(luaUnitFrameSystem, self)
	
	self.luaUnitFrameSystem = luaUnitFrameSystem
	
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 		"OnTutorial_RequestUIAnchor", self)
	Apollo.RegisterEventHandler("KeyBindingKeyChanged", 			"OnKeyBindingUpdated", self)
		
	self.tParams = {
		fScale 			= tParams.fScale or 1,
		nConsoleVar		= tParams.nConsoleVar,
		bDrawClusters 	= tParams.bDrawClusters == nil and true or tParams.bDrawClusters,
		bDrawToT 		= tParams.bDrawToT == nil and true or tParams.bDrawToT,
		bFlipped		= tParams.bFlipped == nil and false or tParams.bFlipped
	}
	
	self.wndMainClusterFrame = Apollo.LoadForm(luaUnitFrameSystem.xmlDoc, tParams.bFlipped and "ClusterTargetFlipped" or "ClusterTarget", "FixedHudStratumLow", self)
	self.arClusterFrames =
	{
		self.wndMainClusterFrame,
		Apollo.LoadForm(luaUnitFrameSystem.xmlDoc, "ClusterTargetMini", "FixedHudStratumLow", self),
		Apollo.LoadForm(luaUnitFrameSystem.xmlDoc, "ClusterTargetMini", "FixedHudStratumLow", self),
		Apollo.LoadForm(luaUnitFrameSystem.xmlDoc, "ClusterTargetMini", "FixedHudStratumLow", self),
		Apollo.LoadForm(luaUnitFrameSystem.xmlDoc, "ClusterTargetMini", "FixedHudStratumLow", self)
	}
	
	self.arClusterFrames[1]:SetScale(self.tParams.fScale)
	self.wndLargeFrame = self.arClusterFrames[1]:FindChild("LargeFrame")
	self:ArrangeClusterMembers()

	self.tPets = { }
	self.wndPetFrame = self.arClusterFrames[1]:FindChild("PetContainerDespawnBtn")
	self.wndToTFrame = self.arClusterFrames[1]:FindChild("TotFrame")
	self.wndToTFrame:Show(false)
	self.arClusterFrames[1]:ArrangeChildrenHorz(1)

	self.wndAssistFrame = Apollo.LoadForm(luaUnitFrameSystem.xmlDoc, "AssistTarget", "FixedHudStratum", self)
	self.wndAssistFrame:Show(false, true)
	self.nAltHealthLeft, self.nAltHealthTop, self.nAltHealthRight, self.nAltHealthBottom = self.wndAssistFrame:FindChild("MaxHealth"):GetAnchorOffsets()
	self.nAltHealthWidth = self.nAltHealthRight - self.nAltHealthLeft

	self.wndSimpleFrame = Apollo.LoadForm(luaUnitFrameSystem.xmlDoc, "SimpleTargetFrame", "FixedHudStratum", self)
	self.wndSimpleFrame:Show(false)

	self.nLFrameLeft, self.nLFrameTop, self.nLFrameRight, self.nLFrameBottom = self.wndLargeFrame:GetAnchorOffsets()
	self.arShieldPos = self.wndLargeFrame:FindChild("MaxShield"):GetLocation()
	self.arAbsorbPos = self.wndLargeFrame:FindChild("MaxAbsorb"):GetLocation()

	-- We apparently resize bars rather than set progress
	self:SetBarValue(self.wndLargeFrame:FindChild("ShieldCapacityTint"), 0, 100, 100)

	self.strPathActionKeybind = GameLib.GetKeyBinding("PathAction")
	self.bPathActionUsesIcon = false
	if self.strPathActionKeybind == "Unbound" or #self.strPathActionKeybind > 1 then -- Don't show interact
		self.bPathActionUsesIcon = true
	end

	self.strQuestActionKeybind = GameLib.GetKeyBinding("CastObjectiveAbility")
	self.bQuestActionUsesIcon = false
	if self.strQuestActionKeybind == "Unbound" or #self.strQuestActionKeybind > 1 then -- Don't show interact
		self.bQuestActionUsesIcon = true
	end

	self.nRaidMarkerLeft, self.nRaidMarkerTop, self.nRaidMarkerRight, self.nRaidMarkerBottom = self.wndLargeFrame:FindChild("RaidMarker"):GetAnchorOffsets()

	self.nLastCCArmorValue = 0
	self.unitLastTarget = nil
	self.bTargetDead = false
end

function TargetFrame:OnUpdate()
	local bTargetChanged = false
	local unitTarget = self.unitTarget
	local unitPlayer = GameLib.GetPlayerUnit()
	local bShowWindow = true
	local tCluster = nil
	
	self.arClusterFrames[1]:Show(self.arClusterFrames[1]:IsShown())
	
	if self.unitLastTarget == nil then
		if unitTarget == nil then
			return
		end
		bTargetChanged = true
		self:HelperResetTooltips() -- these get redrawn with the unitToT info
	end

	if unitTarget ~= nil and self.unitLastTarget ~= unitTarget then
		self.unitLastTarget = unitTarget
		bTargetChanged = true
		self:HelperResetTooltips() -- these get redrawn with the unitToT info
	end
	
	if unitTarget ~= nil then
		-- Cluster info
		tCluster = unitTarget:GetClusterUnits()
		
		if unitTarget == unitPlayer then
			--Treat Mount as a Cluster Target
			if unitPlayer:IsMounted() then
				table.insert(tCluster, unitPlayer:GetUnitMount())
			end
		end
		
		--Make the unit a cluster of a vehicle if they're in one.
		if unitTarget:IsInVehicle() then
			local uPlayer = unitTarget
			unitTarget = uPlayer:GetVehicle()
			
			table.insert(tCluster, uPlayer)
		end
		
		-- Treat Pets as Cluster Targets
		self.wndPetFrame:FindChild("PetContainerDespawnBtn"):SetData(nil)
		
		local tPlayerPets = GameLib.GetPlayerPets()
		self.wndPetFrame:Show(false)
		
		for k,v in ipairs(tPlayerPets) do
			if k == 1 then
				if v == unitTarget then
					self.wndPetFrame:FindChild("PetContainerDespawnBtn"):SetData(v)
					self.wndPetFrame:FindChild("PetContainerDespawnBtn"):SetContentId(GameLib.GetPetDismissCommand(v))
					self.wndPetFrame:Show(true)
				end
			elseif k == 2 then
				if v == unitTarget then
					self.wndPetFrame:FindChild("PetContainerDespawnBtn"):SetData(v)
					self.wndPetFrame:FindChild("PetContainerDespawnBtn"):SetContentId(GameLib.GetPetDismissCommand(v))
					self.wndPetFrame:Show(true)
				end
			end
			
			if k < 3 and unitTarget == unitPlayer then
				table.insert(tCluster, v)
			end
		end
		
		if self.tParams.bDrawClusters ~= true or tCluster == nil or #tCluster < 1 then
			tCluster = nil
		end

		-- Primary frame
		if unitTarget:GetHealth() ~= nil and unitTarget:GetMaxHealth() > 0 then
			self:UpdatePrimaryFrame(unitTarget, bTargetChanged)
		elseif string.len(unitTarget:GetName()) > 0 then
			bShowWindow = false
		end
	else
		bShowWindow = false
		self.wndSimpleFrame:Show(false)
		self:HideClusterFrames()
	end
	
	if bShowWindow and self.tParams.nConsoleVar ~= nil then
		--Toggle Visibility based on ui preference
		local unitPlayer = GameLib.GetPlayerUnit()
		local nVisibility = Apollo.GetConsoleVariable(self.tParams.nConsoleVar)
		
		local nCurrEffHP = unitTarget:GetHealth() + unitTarget:GetShieldCapacity()
		local nMaxEffHP = unitTarget:GetMaxHealth() + unitTarget:GetShieldCapacityMax()
		
		if nVisibility == 2 then --always off
			bShowWindow = false
		elseif nVisibility == 3 then --on in combat
			bShowWindow = unitPlayer:IsInCombat() or nCurrEffHP < nMaxEffHP
		elseif nVisibility == 4 then --on out of combat
			bShowWindow = not unitPlayer:IsInCombat()
		else
			bShowWindow = true
		end
	end
	
	if bShowWindow and tCluster ~= nil and #tCluster > 0 then
		self:UpdateClusterFrame(tCluster)
	else
		self:HideClusterFrames()
	end
	
	self.arClusterFrames[1]:Show(bShowWindow)
end

function TargetFrame:GetPosition()
	return self.arClusterFrames[1]:GetLocation()
end

function TargetFrame:SetPosition(locNewLocation)
	if locNewLocation == nil then
		return
	end
	
	self.arClusterFrames[1]:MoveToLocation(locNewLocation)
end

function TargetFrame:SetTarget(unitTarget)
	self.unitTarget = unitTarget
	self:OnUpdate()
end

-- todo: remove this, move functionality to draw or previous function, look about unhooking for movement
function TargetFrame:UpdatePrimaryFrame(unitTarget, bTargetChanged) --called from the onFrame; eliteness is frame, diff is rank
	self.wndSimpleFrame:Show(false)
	if unitTarget == nil then
		return
	end

	local strTooltipRank = ""
	if unitTarget:GetType() == "Player" then
		local strRank = Apollo.GetString("TargetFrame_IsPC")
		strTooltipRank = self:HelperBuildTooltip(strRank, Apollo.GetString("Achievement_PlayerBtn"))
	elseif ktRankDescriptions[unitTarget:GetRank()] ~= nil then
		local strRank = String_GetWeaselString(Apollo.GetString("TargetFrame_CreatureRank"), ktRankDescriptions[unitTarget:GetRank()][2])
		strTooltipRank = self:HelperBuildTooltip(strRank, ktRankDescriptions[unitTarget:GetRank()][1])
	end

	self.wndLargeFrame:FindChild("TargetModel"):SetTooltip(unitTarget == GameLib.GetPlayerUnit() and "" or strTooltipRank)
	self.wndLargeFrame:FindChild("TargetModel"):SetData(unitTarget)

	self:SetTargetForFrame(self.wndLargeFrame, unitTarget, bTargetChanged)

	-- ToT
	if self.tParams.bDrawToT and not self.wndToTFrame:IsShown() and unitTarget:GetTarget() ~= nil then
		self.wndToTFrame:Show(true)
	elseif self.wndToTFrame:IsShown() and unitTarget:GetTarget() == nil then
		self.wndToTFrame:Show(false)
	end

	if self.wndToTFrame:IsShown() then
		self:UpdateToTFrame(unitTarget:GetTarget())
	end
	
	if RewardIcons ~= nil and RewardIcons.GetUnitRewardIconsForm ~= nil then
		RewardIcons.GetUnitRewardIconsForm(self.wndLargeFrame:FindChild("TargetGoalPanel"), unitTarget, {bVert = true})
	end
	
	-- Raid Marker
	local wndRaidMarker = self.wndLargeFrame:FindChild("RaidMarker")
	if wndRaidMarker then
		wndRaidMarker:SetSprite("")
		local nMarkerId = unitTarget and unitTarget:GetTargetMarker() or 0
		if unitTarget and nMarkerId ~= 0 then
			wndRaidMarker:SetSprite(kstrRaidMarkerToSprite[nMarkerId])
		end
	end

	self.wndLargeFrame:FindChild("TargetModel"):SetCostume(unitTarget)
end


function TargetFrame:UpdateAlternateFrame(unitToT)
	if unitToT == nil then
		return
	end
	local wndFrame = self.wndAssistFrame
	local eDisposition = unitToT:GetDispositionTo(GameLib.GetPlayerUnit())
	local crColorToUse = nil

	if unitToT:IsDead() and (eDisposition ~= Unit.CodeEnumDisposition.Friendly or not unitToT:IsThePlayer()) then
		local unitPlayer = GameLib.GetPlayerUnit()
		unitPlayer:SetAlternateTarget(nil)
		return
	end

	wndFrame:FindChild("TargetName"):SetTextColor(karDispositionColors[eDisposition])
	if unitToT:GetType() == "Player" then
		if eDisposition == Unit.CodeEnumDisposition.Friendly or unitToT:IsThePlayer() then
			if unitToT:IsPvpFlagged() then
				crColorToUse = kcrFlaggedFriendlyTextColor
			elseif unitToT:IsInYourGroup() then
				crColorToUse = kcrGroupTextColor
			else
				crColorToUse = kcrDefaultUnflaggedAllyTextColor
			end
		else
			local bIsUnitFlagged = unitToT:IsPvpFlagged()
			local bAmIFlagged = GameLib.IsPvpFlagged()
			if not bAmIFlagged and not bIsUnitFlagged then
				crColorToUse = kcrNeutralEnemyTextColor
			elseif (bAmIFlagged and not bIsUnitFlagged) or (not bAmIFlagged and bIsUnitFlagged) then
				crColorToUse = kcrAggressiveEnemyTextColor
			elseif bAmIFlagged and bIsUnitFlagged then
				crColorToUse = kcrHostileEnemyTextColor
			end
		end

		wndFrame:FindChild("TargetName"):SetTextColor(crColorToUse)
	end

	wndFrame:FindChild("TargetModel"):SetCostume(unitToT)
	wndFrame:FindChild("TargetModel"):SetData(unitToT)
	wndFrame:SetData(unitToT)
	wndFrame:FindChild("TargetName"):SetText(unitToT:GetName())

	if eDisposition == Unit.CodeEnumDisposition.Friendly or unitToT:IsThePlayer() then
		wndFrame:FindChild("DispositionFrameFriendly"):Show(true)
		wndFrame:FindChild("DispositionFrameHostile"):Show(false)
	else
		wndFrame:FindChild("DispositionFrameFriendly"):Show(false)
		wndFrame:FindChild("DispositionFrameHostile"):Show(true)
	end
	
	local nHealthCurr = unitToT:GetHealth()
	local nHealthMax = unitToT:GetMaxHealth()
	local nShieldCurr = unitToT:GetShieldCapacity()
	local nShieldMax = unitToT:GetShieldCapacityMax()
	local nAbsorbCurr = 0
	local nAbsorbMax = unitToT:GetAbsorptionMax()
	if nAbsorbMax > 0 then
		nAbsorbCurr = unitToT:GetAbsorptionValue() -- Since it doesn't clear when the buff drops off
	end
	local nTotalMax = nHealthMax + nShieldMax + nAbsorbMax

	local nPointHealthRight = self.nAltHealthLeft + (self.nAltHealthWidth * (nHealthCurr / nTotalMax)) -- applied to the difference between L and R
	local nPointShieldRight = self.nAltHealthLeft + (self.nAltHealthWidth * ((nHealthCurr + nShieldMax) / nTotalMax))
	local nPointAbsorbRight = self.nAltHealthLeft + (self.nAltHealthWidth * ((nHealthCurr + nShieldMax + nAbsorbMax) / nTotalMax))

	if nShieldMax > 0 and nShieldMax / nTotalMax < 0.2 then
		local nMinShieldSize = 0.2 -- HARDCODE: Minimum shield bar length is 20% of total for formatting
		nPointHealthRight = self.nAltHealthLeft + (self.nAltHealthWidth * (math.min (1 - nMinShieldSize, nHealthCurr / nTotalMax)))
		nPointShieldRight = self.nAltHealthLeft + (self.nAltHealthWidth * (math.min (1, (nHealthCurr / nTotalMax) + nMinShieldSize)))
	end

	-- Resize
	wndFrame:FindChild("ShieldFill"):EnableGlow(nShieldCurr > 0)
	self:SetBarValue(wndFrame:FindChild("ShieldFill"), 0, nShieldCurr, nShieldMax) -- Only the Curr Shield really progress fills
	self:SetBarValue(wndFrame:FindChild("AbsorbFill"), 0, nAbsorbCurr, nAbsorbMax)
	wndFrame:FindChild("MaxHealth"):SetAnchorOffsets(self.nAltHealthLeft, self.nAltHealthTop, nPointHealthRight, self.nAltHealthBottom)
	wndFrame:FindChild("MaxShield"):SetAnchorOffsets(nPointHealthRight - 1, self.nAltHealthTop, nPointShieldRight, self.nAltHealthBottom)
	wndFrame:FindChild("MaxAbsorb"):SetAnchorOffsets(nPointShieldRight - 1, self.nAltHealthTop, nPointAbsorbRight, self.nAltHealthBottom)

	-- Bars
	wndFrame:FindChild("ShieldFill"):Show(nHealthCurr > 0)
	wndFrame:FindChild("MaxHealth"):Show(nHealthCurr > 0)
	wndFrame:FindChild("MaxShield"):Show(nHealthCurr > 0 and nShieldMax > 0)
	wndFrame:FindChild("MaxAbsorb"):Show(nHealthCurr > 0 and nAbsorbMax > 0)

	-- Text
	local strHealthMax = self:HelperFormatBigNumber(nHealthMax)
	local strHealthCurr = self:HelperFormatBigNumber(nHealthCurr)
	local strShieldCurr = self:HelperFormatBigNumber(nShieldCurr)
	local strText = String_GetWeaselString(Apollo.GetString("TargetFrame_TextProgress"), strHealthCurr, strHealthMax)
	if nShieldMax > 0 and nShieldCurr > 0 then
		strText = String_GetWeaselString(Apollo.GetString("TargetFrame_HealthShieldText"), strText, strShieldCurr)
	end
	wndFrame:FindChild("HealthText"):SetText(strText)

	-- Sprite
	local wndHealth = wndFrame:FindChild("MaxHealth")
	if nVulnerabilityTime and nVulnerabilityTime > 0 then
		wndHealth:SetSprite("sprNp_Health_FillPurple")
	elseif nHealthCurr / nHealthMax < knHealthRed then
		wndHealth:SetSprite("sprNp_Health_FillRed")
	elseif 	nHealthCurr / nHealthMax < knHealthYellow then
		wndHealth:SetSprite("sprNp_Health_FillOrange")
	else
		wndHealth:SetSprite("sprNp_Health_FillGreen")
	end

	-- Interrupt Armor
	---------------------------------------------------------------------------
	local nCCArmorValue = unitToT:GetInterruptArmorValue()
	local nCCArmorMax = unitToT:GetInterruptArmorMax()
	local wndCCArmor = wndFrame:FindChild("CCArmorContainer")

	if nCCArmorMax == 0 or nCCArmorValue == nil then
		wndCCArmor:Show(false)
	else
		wndCCArmor:Show(true)
		if nCCArmorMax == -1 then -- impervious
			wndCCArmor:FindChild("CCArmorValue"):SetText("")
			wndCCArmor:FindChild("CCArmorSprite"):SetSprite("CRB_ActionBarSprites:sprAb_IntArm_Invulnerable")
		elseif nCCArmorValue == 0 and nCCArmorMax > 0 then -- broken
			wndCCArmor:FindChild("CCArmorValue"):SetText("")
			wndCCArmor:FindChild("CCArmorSprite"):SetSprite("CRB_ActionBarSprites:sprAb_IntArm_Broken")
		elseif nCCArmorMax > 0 then -- has armor, has value
			wndCCArmor:FindChild("CCArmorValue"):SetText(nCCArmorValue)
			wndCCArmor:FindChild("CCArmorSprite"):SetSprite("CRB_ActionBarSprites:sprAb_IntArm_Regular")
		end

		if nCCArmorValue < self.nLastCCArmorValue and nCCArmorValue ~= 0 and nCCArmorValue ~= -1 then
			wndCCArmor:FindChild("CCArmorFlash"):SetSprite("CRB_ActionBarSprites:sprAb_IntArm_Flash")
		end
	end

	self:UpdateCastingBar(wndFrame, unitToT)
end


function TargetFrame:UpdateToTFrame(unitToT) -- called on frame
	if unitToT == nil then
		return
	end
	
	--Toggle Visibility based on ui preference
	local unitPlayer = GameLib.GetPlayerUnit()
	local nVisibility = Apollo.GetConsoleVariable("hud.TargetOfTargetFrameDisplay")
	
	if nVisibility == 2 then --always off
		self.wndToTFrame:Show(false)
	elseif nVisibility == 3 then --on in combat
		self.wndToTFrame:Show(unitPlayer:IsInCombat())	
	elseif nVisibility == 4 then --on out of combat
		self.wndToTFrame:Show(not unitPlayer:IsInCombat())
	else
		self.wndToTFrame:Show(true)
	end
	
	if not self.wndToTFrame:IsShown() then
		-- no point in updating something our ui preferences told us not to display...
		return
	end

	self.wndToTFrame:SetData(unitToT)
	self.wndToTFrame:FindChild("TargetModel"):SetCostume(unitToT)
end

function TargetFrame:UpdateClusterFrame(tCluster) -- called on frame
	if self.unitTarget:IsDead() then
		self:HideClusterFrames()
		return
	end

	self:ArrangeClusterMembers()

	local nCount = 2

	for idx = 1, #tCluster do
		if nCount <= 5 then
			if not tCluster[idx]:IsDead() then
				self.arClusterFrames[nCount]:Show(true, true)
				self:SetTargetForClusterFrame(self.arClusterFrames[nCount], tCluster[idx], true)
				self.arClusterFrames[nCount]:FindChild("TargetModel"):SetCostume(tCluster[idx])

				if RewardIcons ~= nil and RewardIcons.GetUnitRewardIconsForm ~= nil then
					RewardIcons.GetUnitRewardIconsForm(self.arClusterFrames[nCount]:FindChild("TargetGoalPanel"), tCluster[idx], {bVert = true})
				end
				
				local nHealth		= tCluster[idx]:GetHealth()
				local nMaxHealth	= tCluster[idx]:GetMaxHealth()
				local nShield		= tCluster[idx]:GetShieldCapacity()
				local nMaxShield	= tCluster[idx]:GetShieldCapacityMax()
				
				if nHealth ~= nil then
					if self.arClusterFrames[nCount]:FindChild("HealthTint") then
						local wndCover = self.arClusterFrames[nCount]:FindChild("Cover")
						local wndHealthBar = self.arClusterFrames[nCount]:FindChild("HealthTint")
						local wndHealthShieldBar = self.arClusterFrames[nCount]:FindChild("HealthShieldTint")
						local wndShieldBar = self.arClusterFrames[nCount]:FindChild("ShieldCapacityTint")
						
						local wndHealth = nMaxShield > 0 and wndHealthShieldBar or wndHealthBar
						wndHealthBar:Show(nMaxShield == 0)
						wndHealthShieldBar:Show(nMaxShield > 0)
						wndShieldBar:Show(nMaxShield > 0)
						wndCover:SetSprite(nMaxShield > 0 and "spr_TargetFrame_ClusterCoverShield" or "spr_TargetFrame_ClusterCover")
						
						wndHealth:SetMax(nMaxHealth)
						wndHealth:SetProgress(nHealth)
						
						wndShieldBar:SetMax(nMaxShield)
						wndShieldBar:SetProgress(nShield)
						
						if tCluster[idx]:IsInCCState(Unit.CodeEnumCCState.Vulnerability) then
							wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthRed")
						elseif (nHealth / nMaxHealth) <= knHealthRed then
							wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthRed")
						elseif (nHealth / nMaxHealth) <= knHealthYellow then
							wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthYellow")
						else
							wndHealth:SetFullSprite("spr_TargetFrame_ClusterHealthGreen")
						end
					end
				end

				local nLevel = tCluster[idx]:GetLevel()
				if nLevel == nil then
					self.arClusterFrames[nCount]:FindChild("TargetLevel"):SetText("--")
					self.arClusterFrames[nCount]:FindChild("TargetLevel"):SetTextColor(karConInfo[1][2])
					self.arClusterFrames[nCount]:FindChild("TargetLevel"):SetTooltip("")
				else
					local nCon = self:HelperCalculateConValue(tCluster[idx])
					self.arClusterFrames[nCount]:FindChild("TargetLevel"):SetText(tCluster[idx]:GetLevel())
					
					if tCluster[idx]:IsScaled() then
						self.arClusterFrames[nCount]:FindChild("TargetScalingMark"):Show(true)
						self.arClusterFrames[nCount]:FindChild("TargetLevel"):SetTextColor(kcrScalingCColor)
						
						if tCluster[idx] ~= GameLib.GetPlayerUnit() then
							strRewardFormatted = String_GetWeaselString(Apollo.GetString("TargetFrame_CreatureScales"), tCluster[idx]:GetLevel())
							local strLevelTooltip = self:HelperBuildTooltip(strRewardFormatted, Apollo.GetString("Adaptive"), kstrScalingHex)
							self.arClusterFrames[nCount]:FindChild("TargetLevel"):FindChild("TargetLevel"):SetTooltip(strLevelTooltip)
						end
					else
						self.arClusterFrames[nCount]:FindChild("TargetLevel"):SetTextColor(karConInfo[nCon][2])
						
						if tCluster[idx] ~= GameLib.GetPlayerUnit() then
							local strRewardFormatted = String_GetWeaselString(Apollo.GetString("TargetFrame_TargetXPReward"), karConInfo[nCon][4])
							local strLevelTooltip = self:HelperBuildTooltip(strRewardFormatted, karConInfo[nCon][3], karConInfo[nCon][5])
							self.arClusterFrames[nCount]:FindChild("TargetLevel"):SetTooltip(strLevelTooltip)
						end
					end
				end

				nCount = nCount + 1
			end
		end
	end

	for idx = nCount, 5 do
		self.arClusterFrames[idx]:Show(false)
		self.arClusterFrames[idx]:SetData(nil)
	end
end

function TargetFrame:HideClusterFrames()
	for idx = 2, 5 do
		self.arClusterFrames[idx]:Show(false)
		self.arClusterFrames[idx]:SetData(nil)
	end
end

function TargetFrame:SetTargetForFrame(wndFrame, unitTarget, bTargetChanged)
	wndFrame:SetData(unitTarget)
	self:SetTargetHealthAndShields(wndFrame, unitTarget)

	if unitTarget then
		strName = unitTarget:GetName()
		-- PvP
		if unitTarget:IsPvpFlagged() then
			strName = String_GetWeaselString(Apollo.GetString("BaseBar_PvPAppend"), strName)
		end
		
		wndFrame:FindChild("TargetName"):SetText(strName)

		local eRank = unitTarget:GetRank()
		local strClassIconSprite = ""
		local strPlayerIconSprite = ""
		
		-- Class Icon is based on player class or NPC rank
		if unitTarget:GetType() == "Player" then
			strPlayerIconSprite = karClassToIcon[unitTarget:GetClassId()]
		elseif eRank == Unit.CodeEnumRank.Elite then
			strClassIconSprite = "spr_TargetFrame_ClassIcon_Elite"
		elseif eRank == Unit.CodeEnumRank.Superior then
			strClassIconSprite = "spr_TargetFrame_ClassIcon_Superior"
		elseif eRank == Unit.CodeEnumRank.Champion then
			strClassIconSprite = "spr_TargetFrame_ClassIcon_Champion"
		elseif eRank == Unit.CodeEnumRank.Standard then
			strClassIconSprite = "spr_TargetFrame_ClassIcon_Standard"
		elseif eRank == Unit.CodeEnumRank.Minion then
			strClassIconSprite = "spr_TargetFrame_ClassIcon_Minion"
		elseif eRank == Unit.CodeEnumRank.Fodder then
			strClassIconSprite = "spr_TargetFrame_ClassIcon_Fodder"
		end
		
		wndFrame:FindChild("TargetIconShadow"):Show(strPlayerIconSprite ~= "" or strClassIconSprite ~= "")
		wndFrame:FindChild("PlayerClassIcon"):SetSprite(strPlayerIconSprite)
		wndFrame:FindChild("TargetClassIcon"):SetSprite(strClassIconSprite)
		
		--Disposition/flags
		local strFlipped = self.tParams.bFlipped and "Flipped" or ""
		local eDisposition = unitTarget:GetDispositionTo(GameLib.GetPlayerUnit())
		local strDisposition = "Friendly"
		local strAttachment = ""

		wndFrame:FindChild("TargetName"):SetTextColor(karDispositionColors[eDisposition])
		
		if eDisposition == Unit.CodeEnumDisposition.Hostile then
			strDisposition = "Hostile"
		elseif eDisposition == Unit.CodeEnumDisposition.Neutral then
			strDisposition = "Neutral"
		end
		
		--Rare and Elite NPCs
		if unitTarget:GetDifficulty() == 3 then
			strAttachment = strDisposition.."Rare"
		elseif unitTarget:GetDifficulty() == 7 then
			strAttachment = strDisposition.."Elite"
		end
		
		--Unit in Vehicle
		if self.unitTarget:IsInVehicle() then
			strAttachment = "Vehicle"
		end
		
		--Iconic and Max Level Players
		local idArchetype = unitTarget:GetArchetype() and unitTarget:GetArchetype().idArchetype or 0
		local strFaction = karFactionToString[unitTarget:GetFaction()] or ""
		if (idArchetype == knIconicArchetype or (unitTarget:GetType() == "Player" and unitTarget:GetLevel() == knMaxLevel)) then
			strAttachment = eDisposition == Unit.CodeEnumDisposition.Friendly and "FriendlyIconic" or "HostileIconic"
			strAttachment = strAttachment .. strFaction
		end
		
		self.wndLargeFrame:FindChild("Attachment"):SetSprite("spr_TargetFrame_Frame"..strAttachment..strFlipped)
		self.wndLargeFrame:FindChild("Backer"):SetSprite("spr_TargetFrame_Frame"..strDisposition..strFlipped)
		self.wndLargeFrame:FindChild("HealthSplit"):SetSprite("spr_TargetFrame_HealthSplit"..strDisposition..strFlipped)
		
		if (unitTarget:IsDead() or (unitTarget:IsTagged() and not unitTarget:IsTaggedByMe())) then
			self.wndLargeFrame:FindChild("Backer"):SetSprite("spr_TargetFrame_FrameTapped"..strFlipped)
		end
		
		local unitToT = unitTarget:GetTarget()
		if unitToT ~= nil then
			local eToTDisposition = unitToT:GetDispositionTo(GameLib.GetPlayerUnit())
			
			if eToTDisposition == Unit.CodeEnumDisposition.Hostile then
				self.wndToTFrame:FindChild("Backer"):SetSprite("spr_TargetFrame_ToTHostile")
				self.wndToTFrame:FindChild("DispositionFrame"):SetBGColor(ApolloColor.new("ffff6d66"))
			elseif eToTDisposition == Unit.CodeEnumDisposition.Neutral then
				self.wndToTFrame:FindChild("Backer"):SetSprite("spr_TargetFrame_ToTNeutral")
				self.wndToTFrame:FindChild("DispositionFrame"):SetBGColor(ApolloColor.new("fffaff66"))
			else
				self.wndToTFrame:FindChild("Backer"):SetSprite("spr_TargetFrame_ToTFriendly")
				self.wndToTFrame:FindChild("DispositionFrame"):SetBGColor(ApolloColor.new("ff00f7de"))
			end
			
			self.wndToTFrame:FindChild("DispositionFrame"):SetTooltip(ktDispositionToTTooltip[eToTDisposition])
		end

		--todo: Tooltips
		local bSameFaction = GameLib.GetPlayerUnit():GetFaction() == unitTarget:GetFaction()
		local crColorToUse = karDispositionColors[eDisposition]

		-- Level / Diff
		local nLevel = unitTarget:GetLevel()
		if nLevel == nil then
			wndFrame:FindChild("TargetLevel"):SetText(Apollo.GetString("CRB__2"))
			wndFrame:FindChild("TargetLevel"):SetTextColor(karConInfo[1][2])
			wndFrame:FindChild("TargetLevel"):SetTooltip("")
		else
			wndFrame:FindChild("TargetLevel"):SetText(unitTarget:GetLevel())

			if unitTarget:IsScaled() then
				wndFrame:FindChild("TargetScalingMark"):Show(true)
				wndFrame:FindChild("TargetLevel"):SetTextColor(kcrScalingCColor)
				
				if unitTarget ~= GameLib.GetPlayerUnit() then
					strRewardFormatted = String_GetWeaselString(Apollo.GetString("TargetFrame_CreatureScales"), unitTarget:GetLevel())
					local strLevelTooltip = self:HelperBuildTooltip(strRewardFormatted, Apollo.GetString("Adaptive"), kcrScalingHex)
					wndFrame:FindChild("TargetLevel"):FindChild("TargetLevel"):SetTooltip(strLevelTooltip)
				end
			else
				wndFrame:FindChild("TargetScalingMark"):Show(false)
				local nCon = self:HelperCalculateConValue(unitTarget)
				wndFrame:FindChild("TargetLevel"):SetTextColor(karConInfo[nCon][2])
				
				if unitTarget ~= GameLib.GetPlayerUnit() then
					strRewardFormatted = String_GetWeaselString(Apollo.GetString("TargetFrame_TargetXPReward"), karConInfo[nCon][4])
					local strLevelTooltip = self:HelperBuildTooltip(strRewardFormatted, karConInfo[nCon][3], karConInfo[nCon][5])
					wndFrame:FindChild("TargetLevel"):FindChild("TargetLevel"):SetTooltip(strLevelTooltip)
				end
			end
		end

		local strUnitType = unitTarget:GetType()
		if strUnitType == "Player" or strUnitType == "Pet" or strUnitType == "Esper Pet" then
			local unitPlayer = unitTarget:GetUnitOwner() or unitTarget
			if eDisposition == Unit.CodeEnumDisposition.Friendly or unitPlayer:IsThePlayer() then
				if unitPlayer:IsPvpFlagged() then
					crColorToUse = kcrFlaggedFriendlyTextColor
				elseif unitPlayer:IsInYourGroup() then
					crColorToUse = kcrGroupTextColor
				else
					crColorToUse = kcrDefaultUnflaggedAllyTextColor
				end
			else
				local bIsUnitFlagged = unitPlayer:IsPvpFlagged()
				local bAmIFlagged = GameLib.IsPvpFlagged()
				if not bAmIFlagged and not bIsUnitFlagged then
					crColorToUse = kcrNeutralEnemyTextColor
				elseif (bAmIFlagged and not bIsUnitFlagged) or (not bAmIFlagged and bIsUnitFlagged) then
					crColorToUse = kcrAggressiveEnemyTextColor
				end
			end
			wndFrame:FindChild("GroupSizeMark"):Show(false)
			wndFrame:FindChild("TargetName"):SetTextColor(crColorToUse)
		else -- NPC
			wndFrame:FindChild("GroupSizeMark"):Show(unitTarget:GetGroupValue() > 0)
			wndFrame:FindChild("GroupSizeMark"):SetText(unitTarget:GetGroupValue())

			local strGroupTooltip = self:HelperBuildTooltip(String_GetWeaselString(Apollo.GetString("TargetFrame_GroupSize"), unitTarget:GetGroupValue()), String_GetWeaselString(Apollo.GetString("TargetFrame_Man"), unitTarget:GetGroupValue()))
			wndFrame:FindChild("GroupSizeMark"):SetTooltip(strGroupTooltip)
		end

		-- Interrupt Armor
		---------------------------------------------------------------------------
		local nCCArmorValue = unitTarget:GetInterruptArmorValue()
		local nCCArmorMax = unitTarget:GetInterruptArmorMax()
		local wndCCArmor = wndFrame:FindChild("CCArmor")

		if nCCArmorMax == -1 then -- impervious
			wndCCArmor:Show(true)
			wndCCArmor:SetText("")
			wndCCArmor:SetSprite("spr_TargetFrame_InterruptArmor_Infinite")
		elseif nCCArmorMax > 0 then -- has armor, has value
			wndCCArmor:Show(true)
			wndCCArmor:SetText(nCCArmorValue)
			wndCCArmor:SetSprite("spr_TargetFrame_InterruptArmor_Value")
		else
			wndCCArmor:Show(false)
		end
	end

	if bTargetChanged then
		for idx = 1, 8 do
			wndFrame:FindChild("BeneBuffBar"):SetUnit(unitTarget)
			wndFrame:FindChild("HarmBuffBar"):SetUnit(unitTarget)
		end
	end

	self:UpdateCastingBar(wndFrame, unitTarget)
end

function TargetFrame:SetTargetForClusterFrame(wndFrame, unitTarget, bTargetChanged) -- this is the update; we can split here
	wndFrame:SetData(unitTarget)

	local eRank = unitTarget:GetRank()
	
	if unitTarget then
		if not unitTarget == GameLib.GetPlayerMountUnit() then
			local strTooltipRank = ""
			if ktRankDescriptions[unitTarget:GetRank()] ~= nil then
				local strRank = String_GetWeaselString(Apollo.GetString("TargetFrame_CreatureRank"), ktRankDescriptions[unitTarget:GetRank()][2])
				strTooltipRank = self:HelperBuildTooltip(strRank, ktRankDescriptions[unitTarget:GetRank()][1])
			end
			
			wndFrame:FindChild("TargetModel"):SetTooltip(unitTarget == GameLib.GetPlayerUnit() and "" or strTooltipRank)

			if unitTarget:GetArchetype() and wndFrame:FindChild("TargetClassIcon") then
				wndFrame:FindChild("TargetClassIcon"):SetSprite(unitTarget:GetArchetype().strIcon)
			end
		else
			local nCurHealth = unitTarget:GetHealth() or 0
			local nMaxHealth = unitTarget:GetMaxHealth() or 0
			local strHealthCurr = self:HelperFormatBigNumber(nCurHealth)
			local strHealthMax = self:HelperFormatBigNumber(nMaxHealth)
			
			local strTooltip = string.format("%s: %s / %s (%s)", Apollo.GetString("Innate_Health"), strHealthCurr, strHealthMax, String_GetWeaselString(Apollo.GetString("CRB_Percent"), nCurHealth/nMaxHealth*100))
		
			local strShieldTooltip 
			if unitTarget:GetShieldCapacityMax() ~= 0 then
				local nCurShield = unitTarget:GetShieldCapacity() or 0
				local nMaxShield = unitTarget:GetShieldCapacityMax() or 0
				local strShieldCurr = self:HelperFormatBigNumber(nCurShield)
				local strShieldMax = self:HelperFormatBigNumber(nMaxShield)
				strShieldTooltip = string.format("%s: %s / %s (%s)", Apollo.GetString("Character_ShieldLabel"), strShieldCurr, strShieldMax, String_GetWeaselString(Apollo.GetString("CRB_Percent"), nCurShield/nMaxShield*100))
			end
			strTooltip = string.format("%s\n%s\n%s", unitTarget:GetName() ,strTooltip, strShieldTooltip or "")
			wndFrame:SetTooltip(strTooltip)			
		end
	end

	self:UpdateCastingBar(wndFrame, unitTarget)
end

function TargetFrame:UpdateCastingBar(wndFrame, unitCaster)
	-- Casting Bar Update

	local bShowCasting = false
	local bEnableGlow = false
	local nZone = 0
	local nMaxZone = 0
	local nDuration = 0
	local nElapsed = 0
	local strSpellName = ""
	local nElapsed = 0
	local eType = Unit.CodeEnumCastBarType.None
	local strIcon = ""
	local strFillSprite = ""
	local strBaseSprite = ""
	local strGlowSprite = ""

	local wndCastFrame = wndFrame:FindChild("CastingFrame")
	local wndCastProgress = wndFrame:FindChild("CastingBar")
	local wndCastName = wndFrame:FindChild("CastingName")
	local wndCastIcon = wndFrame:FindChild("CastingIcon")
	local wndCastBase = wndFrame:FindChild("CastingBase")

	-- results for GetCastBarType can be:
	-- Unit.CodeEnumCastBarType.None
	-- Unit.CodeEnumCastBarType.Normal
	-- Unit.CodeEnumCastBarType.Telegraph_Backlash
	-- Unit.CodeEnumCastBarType.Telegraph_Evade
	if unitCaster:ShouldShowCastBar() then
		eType = unitCaster:GetCastBarType()

		if eType == Unit.CodeEnumCastBarType.Telegraph_Evade then
			strIcon = "CRB_TargetFrameSprites:sprTF_CastIconEvade"
		elseif eType == Unit.CodeEnumCastBarType.Telegraph_Backlash then
			strIcon = "CRB_TargetFrameSprites:sprTF_CastIconInterrupt"
		else
			strIcon = ""
		end

		if eType ~= Unit.CodeEnumCastBarType.None then

			bShowCasting = true
			bEnableGlow = true
			nZone = 0
			nMaxZone = 1
			nDuration = unitCaster:GetCastDuration()
			nElapsed = unitCaster:GetCastElapsed()
			if wndCastProgress ~= nil then
				wndCastProgress:SetTickLocations(0, 100, 200, 300)
			end

			strSpellName = unitCaster:GetCastName()
		end
	end

	wndCastFrame:Show(bShowCasting)
	if wndCastProgress ~= nil then
		wndCastProgress:Show(bShowCasting)
		wndCastName:Show(bShowCasting)
	end

	if bShowCasting and nDuration > 0 and nMaxZone > 0 then
		wndCastIcon:SetSprite(nIcon)

		if wndCastProgress ~= nil then
			-- add a countdown timer if nDuration is > 4.999 seconds.
			local strDuration = nDuration > 4999 and " (" .. string.format("%00.01f", (nDuration-nElapsed)/1000)..")" or ""
			
			wndCastProgress:Show(bShowCasting)
			wndCastProgress:SetMax(nDuration)
			wndCastProgress:SetProgress(nElapsed)
			wndCastProgress:EnableGlow(bEnableGlow)
			wndCastName:SetText(strSpellName .. strDuration)
		end
	end

end

-------------------------------------------------------------------------------
function TargetFrame:ArrangeClusterMembers()
	local nFrameLeft, nFrameTop, nFrameRight, nFrameBottom = self.arClusterFrames[1]:GetRect()

	if self.nFrameLeft == nil or nFrameLeft ~= self.nFrameLeft or nFrameTop ~= self.nFrameTop then -- if the frame has been moved since we last drew
		-- set new variables
		self.nFrameLeft = nFrameLeft
		self.nFrameTop = nFrameTop
		self.nFrameRight = nFrameRight
		self.nFrameBottom = nFrameBottom
		
		if self.tParams.bFlipped then
			self.arClusterFrames[2]:Move(self.nFrameRight-knClusterFrameWidth*1, self.nFrameTop + knClusterFrameVertOffset, knClusterFrameWidth, knClusterFrameHeight)
			self.arClusterFrames[3]:Move(self.nFrameRight-knClusterFrameWidth*2, self.nFrameTop + knClusterFrameVertOffset, knClusterFrameWidth, knClusterFrameHeight)
			self.arClusterFrames[4]:Move(self.nFrameRight-knClusterFrameWidth*3, self.nFrameTop + knClusterFrameVertOffset, knClusterFrameWidth, knClusterFrameHeight)
			self.arClusterFrames[5]:Move(self.nFrameRight-knClusterFrameWidth*4, self.nFrameTop + knClusterFrameVertOffset, knClusterFrameWidth, knClusterFrameHeight)
		else
			self.arClusterFrames[2]:Move(self.nFrameLeft+knClusterFrameWidth*0, self.nFrameTop + knClusterFrameVertOffset, knClusterFrameWidth, knClusterFrameHeight)
			self.arClusterFrames[3]:Move(self.nFrameLeft+knClusterFrameWidth*1, self.nFrameTop + knClusterFrameVertOffset, knClusterFrameWidth, knClusterFrameHeight)
			self.arClusterFrames[4]:Move(self.nFrameLeft+knClusterFrameWidth*2, self.nFrameTop + knClusterFrameVertOffset, knClusterFrameWidth, knClusterFrameHeight)
			self.arClusterFrames[5]:Move(self.nFrameLeft+knClusterFrameWidth*3, self.nFrameTop + knClusterFrameVertOffset, knClusterFrameWidth, knClusterFrameHeight)
		end
	end
end

function TargetFrame:HelperBuildTooltip(strBody, strTitle, crTitleColor)
	if strBody == nil then return end
	local strTooltip = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"%s\">%s</T>", kstrTooltipBodyColor, strBody)
	if strTitle ~= nil then -- if a title has been passed, add it (optional)
		strTooltip = string.format("<P>%s</P>", strTooltip)
		local strTitle = string.format("<P Font=\"CRB_InterfaceMedium_B\" TextColor=\"%s\">%s</P>", crTitleColor or kstrTooltipTitleColor, strTitle)
		strTooltip = strTitle .. strTooltip
	end
	return strTooltip
end

function TargetFrame:HelperCalculateConValue(unitTarget)
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

function TargetFrame:HelperResetTooltips()
	self.wndLargeFrame:FindChild("TargetModel"):SetTooltip("")
	self.wndLargeFrame:FindChild("TargetLevel"):SetTooltip("")
	self.wndLargeFrame:FindChild("GroupSizeMark"):SetTooltip("")
end

function TargetFrame:SetTargetHealthAndShields(wndTargetFrame, unitTarget)
	if not unitTarget or unitTarget:GetHealth() == nil then
		return
	end

	if unitTarget:GetType() == "Simple" then -- String Comparison, should replace with an enum
		self.wndLargeFrame:FindChild("HealthText"):SetText("")
		self.wndLargeFrame:FindChild("MaxShield"):Show(false)
		self.wndLargeFrame:FindChild("MaxAbsorb"):Show(false)
		return
	end

	local nHealthCurr = unitTarget:GetHealth()
	local nHealthMax = unitTarget:GetMaxHealth()
	local nShieldCurr = unitTarget:GetShieldCapacity()
	local nShieldMax = unitTarget:GetShieldCapacityMax()
	local nAbsorbCurr = 0
	local nAbsorbMax = unitTarget:GetAbsorptionMax()
	if nAbsorbMax > 0 then
		nAbsorbCurr = unitTarget:GetAbsorptionValue() -- Since it doesn't clear when the buff drops off
	end
	local nTotalMax = nHealthMax + nShieldMax + nAbsorbMax
	
	local strFlipped = self.tParams.bFlipped and "Flipped" or ""
	local wndHealth =  self.wndLargeFrame:FindChild("HealthCapacityTint")
	if unitTarget:IsInCCState(Unit.CodeEnumCCState.Vulnerability) then
		wndHealth:SetFullSprite("spr_TargetFrame_HealthFillVulernable"..strFlipped)
	elseif nHealthCurr / nHealthMax <= knHealthRed then
		wndHealth:SetFullSprite("spr_TargetFrame_HealthFillRed"..strFlipped)
	elseif nHealthCurr / nHealthMax <= knHealthYellow then
		wndHealth:SetFullSprite("spr_TargetFrame_HealthFillYellow"..strFlipped)
	else
		wndHealth:SetFullSprite("spr_TargetFrame_HealthFillGreen"..strFlipped)
	end
	
	wndHealth:SetStyleEx("EdgeGlow", nHealthCurr / nHealthMax < 0.96)

	-- Resize
	self:SetBarValue(self.wndLargeFrame:FindChild("ShieldCapacityTint"), 0, nShieldCurr, nShieldMax) -- Only the Curr Shield really progress fills
	self:SetBarValue(self.wndLargeFrame:FindChild("AbsorbCapacityTint"), 0, nAbsorbCurr, nAbsorbMax)

	-- Bars
	self.wndLargeFrame:FindChild("HealthCapacityTint"):SetMax(nHealthMax);
	self.wndLargeFrame:FindChild("HealthCapacityTint"):SetProgress(nHealthCurr);
	
	self.wndLargeFrame:FindChild("ShieldCapacityTint"):SetMax(nShieldMax);
	self.wndLargeFrame:FindChild("ShieldCapacityTint"):SetProgress(nShieldCurr);
	
	self.wndLargeFrame:FindChild("AbsorbCapacityTint"):SetMax(nAbsorbMax);
	self.wndLargeFrame:FindChild("AbsorbCapacityTint"):SetProgress(nAbsorbCurr);
	
	self.wndLargeFrame:FindChild("MaxShield"):Show(nShieldCurr > 0 and nShieldMax > 0)-- and unitTarget:ShouldShowShieldCapacityBar())
	self.wndLargeFrame:FindChild("MaxAbsorb"):Show(nAbsorbCurr > 0 and nAbsorbMax > 0)-- and unitTarget:ShouldShowShieldCapacityBar())
	self.wndLargeFrame:FindChild("MaxAbsorb"):MoveToLocation(self.wndLargeFrame:FindChild("MaxShield"):IsShown() and self.arAbsorbPos or self.arShieldPos)

	if not self.wndLargeFrame:FindChild("MaxShield"):IsShown() and not self.wndLargeFrame:FindChild("MaxAbsorb"):IsShown() then
		-- reduce by 2
		if self.tParams.bFlipped then
			self.wndLargeFrame:SetAnchorOffsets(self.nLFrameRight-knFrameWidthMin, self.nLFrameTop, self.nLFrameRight, self.nLFrameBottom)
		else
			self.wndLargeFrame:SetAnchorOffsets(self.nLFrameLeft, self.nLFrameTop, self.nLFrameLeft+knFrameWidthMin, self.nLFrameBottom)
		end
		self.wndLargeFrame:FindChild("HealthSplit"):Show(false)
	elseif not self.wndLargeFrame:FindChild("MaxShield"):IsShown() or not self.wndLargeFrame:FindChild("MaxAbsorb"):IsShown() then
		-- reduce by 1
		if self.tParams.bFlipped then
			self.wndLargeFrame:SetAnchorOffsets(self.nLFrameRight-knFrameWidthShield, self.nLFrameTop, self.nLFrameRight, self.nLFrameBottom)
		else
			self.wndLargeFrame:SetAnchorOffsets(self.nLFrameLeft, self.nLFrameTop, self.nLFrameLeft+knFrameWidthShield, self.nLFrameBottom)
		end
		self.wndLargeFrame:FindChild("HealthSplit"):Show(true)
	else
		if self.tParams.bFlipped then
			self.wndLargeFrame:SetAnchorOffsets(self.nLFrameRight-knFrameWidthMax, self.nLFrameTop, self.nLFrameRight, self.nLFrameBottom)
		else
			self.wndLargeFrame:SetAnchorOffsets(self.nLFrameLeft, self.nLFrameTop, self.nLFrameLeft+knFrameWidthMax, self.nLFrameBottom)
		end
		self.wndLargeFrame:FindChild("HealthSplit"):Show(true)
	end

	-- String
	local strHealthMax = self:HelperFormatBigNumber(nHealthMax)
	local strHealthCurr = self:HelperFormatBigNumber(nHealthCurr)
	local strShieldCurr = self:HelperFormatBigNumber(nShieldCurr)
	local strShieldMax = self:HelperFormatBigNumber(nShieldMax)
	local strAbsorbCurr = self:HelperFormatBigNumber(nAbsorbCurr)
	local strAbsorbMax = self:HelperFormatBigNumber(nAbsorbMax)
	
	local nVisibility = Apollo.GetConsoleVariable("hud.healthTextDisplay")
	
	local strTextXY = (nVisibility == 2) and String_GetWeaselString(Apollo.GetString("TargetFrame_HealthText"), strHealthCurr, strHealthMax) or ""
	local strTextPCT = (nVisibility == 3) and String_GetWeaselString(Apollo.GetString("CRB_Percent"), nHealthCurr/nHealthMax*100) or ""
	local strTooltip = string.format("%s: %s / %s (%s)", Apollo.GetString("Innate_Health"), strHealthCurr, strHealthMax, String_GetWeaselString(Apollo.GetString("CRB_Percent"), nHealthCurr/nHealthMax*100))
	
	if nShieldMax > 0 and nShieldCurr > 0 then
		if nVisibility == 2 then
			strTextXY = String_GetWeaselString(Apollo.GetString("TargetFrame_HealthShieldText"), strTextXY, strShieldCurr)
		elseif nVisibility == 3 and nShieldCurr/nShieldMax ~= nHealthCurr/nHealthMax then
			strTextPCT = String_GetWeaselString(Apollo.GetString("TargetFrame_HealthShieldText"), strTextPCT, String_GetWeaselString(Apollo.GetString("CRB_Percent"), nShieldCurr/nShieldMax*100))
		end
		
		local strShieldTooltip = string.format("%s: %s / %s (%s)", Apollo.GetString("Character_ShieldLabel"), strShieldCurr, strShieldMax, String_GetWeaselString(Apollo.GetString("CRB_Percent"), nShieldCurr/nShieldMax*100))
		strTooltip = string.format("%s\n%s", strTooltip, strShieldTooltip)
	end
	
	if nAbsorbMax > 0 and nAbsorbCurr > 0 then
		local strAbsorbTooltip = string.format("%s: %s / %s (%s)", Apollo.GetString("FloatText_AbsorbTester"), strAbsorbCurr, strAbsorbMax, String_GetWeaselString(Apollo.GetString("CRB_Percent"), nAbsorbCurr/nAbsorbMax*100))
		strTooltip = string.format("%s\n%s", strTooltip, strAbsorbTooltip)
	end
	
	--Toggle Visibility based on ui preference
	if nVisibility == 2 then -- show x/y
		self.wndLargeFrame:FindChild("HealthText"):SetText(strTextXY)
	elseif nVisibility == 3 then --show %
		self.wndLargeFrame:FindChild("HealthText"):SetText(strTextPCT)
	else --on mouseover
		self.wndLargeFrame:FindChild("HealthText"):SetText("")
	end
	
	self.wndLargeFrame:FindChild("HealthText"):SetTooltip(strTooltip)
end


function TargetFrame:HelperFormatBigNumber(nArg)
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

function TargetFrame:SetBarValue(wndBar, fMin, fValue, fMax)
	wndBar:SetMax(fMax)
	wndBar:SetFloor(fMin)
	wndBar:SetProgress(fValue)
end

function TargetFrame:OnGenerateBuffTooltip(wndHandler, wndControl, tType, splBuff)
	if wndHandler == wndControl then
		return
	end
	Tooltip.GetBuffTooltipForm(self, wndControl, splBuff, {bFutureSpell = false})
end

function TargetFrame:OnMouseButtonDown(wndHandler, wndControl, eMouseButton, x, y)
	local unitToT = wndHandler:GetData()
	if eMouseButton == GameLib.CodeEnumInputMouse.Left and unitToT ~= nil then
		GameLib.SetTargetUnit(unitToT)
		return false
	end
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and unitToT ~= nil then
		Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", nil, unitToT:GetName(), unitToT)
		return true
	end

	if IsDemo() then
		return true
	end

	return false
end

function TargetFrame:OnQueryDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)
	if wndHandler ~= wndControl then
		return Apollo.DragDropQueryResult.PassOn
	end

	local unitToT = GameLib.GetTargetUnit()
	if unitToT == nil then
		return Apollo.DragDropQueryResult.Invalid
	end
	if unitToT:IsACharacter() and not unitToT:IsThePlayer() and strType == "DDBagItem" then
		return Apollo.DragDropQueryResult.Accept
	end
	return Apollo.DragDropQueryResult.Invalid
end

function TargetFrame:OnDragDrop(wndHandler, wndControl, nX, nY, wndSource, strType, nValue)
	if wndHandler ~= wndControl then
		return false
	end

	local unitToT = GameLib.GetTargetUnit()
	if unitToT == nil then
		return false
	end
	if unitToT:IsACharacter() and not unitToT:IsThePlayer() and strType == "DDBagItem" then
		Event_FireGenericEvent("ItemDropOnTarget", unit, strType, nValue)
		return false
	end
end

function TargetFrame:OnKeyBindingUpdated(strKeybind)
	if strKeybind ~= "Path Action" and strKeybind ~= "Cast Objective Ability" then
		return
	end

	self.strPathActionKeybind = GameLib.GetKeyBinding("PathAction")
	self.bPathActionUsesIcon = false
	if self.strPathActionKeybind == "Unbound" or #self.strPathActionKeybind > 1 then -- Don't show interact
		self.bPathActionUsesIcon = true
	end

	self.strQuestActionKeybind = GameLib.GetKeyBinding("CastObjectiveAbility")
	self.bQuestActionUsesIcon = false
	if self.strQuestActionKeybind == "Unbound" or #self.strQuestActionKeybind > 1 then -- Don't show interact
		self.bQuestActionUsesIcon = true
	end
end

function TargetFrame:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor == GameLib.CodeEnumTutorialAnchor.BuffFrame then
		local tRect = {}
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndLargeFrame:FindChild("BeneBuffBar"):GetRect()
		Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	end
end

local UnitFramesInstance = UnitFrames:new()
UnitFrames:Init()