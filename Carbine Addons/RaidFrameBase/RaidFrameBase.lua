-------------------------------------------------------------------------------------------
-- Client Lua Script for RaidFrameBase
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "bit32"

local RaidFrameBase = {}

local ktIdToClassSprite =
{
	[GameLib.CodeEnumClass.Esper] 			= "Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "Icon_Windows_UI_CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Warrior] 		= "Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Spellslinger] 	= "Icon_Windows_UI_CRB_Spellslinger",
}

local ktIdToClassTooltip =
{
	[GameLib.CodeEnumClass.Esper] 			= "CRB_Esper",
	[GameLib.CodeEnumClass.Medic] 			= "CRB_Medic",
	[GameLib.CodeEnumClass.Stalker] 		= "ClassStalker",
	[GameLib.CodeEnumClass.Warrior] 		= "CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "CRB_Engineer",
	[GameLib.CodeEnumClass.Spellslinger] 	= "CRB_Spellslinger",
}

local ktIdToRoleSprite =  -- -1 is valid
{
	[-1] = "",
	[MatchingGame.Roles.Tank] 	= "sprRaid_Icon_RoleTank",
	[MatchingGame.Roles.Healer] = "sprRaid_Icon_RoleHealer",
	[MatchingGame.Roles.DPS] 	= "sprRaid_Icon_RoleDPS",
}

local ktIdToRoleTooltip =
{
	[-1] = "",
	[MatchingGame.Roles.Tank] 	= "Matching_Role_Tank",
	[MatchingGame.Roles.Healer] = "Matching_Role_Healer",
	[MatchingGame.Roles.DPS] 	= "Matching_Role_Dps",
}

local ktIdToLeaderSprite =  -- 0 is valid
{
	[0] = "",
	[1] = "CRB_Raid:sprRaid_Icon_Leader",
	[2] = "CRB_Raid:sprRaid_Icon_TankLeader",
	[3] = "CRB_Raid:sprRaid_Icon_AssistLeader",
	[4] = "CRB_Raid:sprRaid_Icon_2ndLeader",
}

local ktIdToLeaderTooltip =
{
	[0] = "",
	[1] = "RaidFrame_RaidLeader",
	[2] = "RaidFrame_MainTank",
	[3] = "RaidFrame_CombatAssist",
	[4] = "RaidFrame_RaidAssist",
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

local ktLootModeToString =
{
	[GroupLib.LootRule.Master] 			= "Group_MasterLoot",
	[GroupLib.LootRule.RoundRobin] 		= "Group_RoundRobin",
	[GroupLib.LootRule.FreeForAll] 		= "Group_FFA",
	[GroupLib.LootRule.NeedBeforeGreed] = "Group_NeedVsGreed",
}

local ktItemQualityToStr =
{
	[Item.CodeEnumItemQuality.Inferior] 		= Apollo.GetString("CRB_Inferior"),
	[Item.CodeEnumItemQuality.Average] 			= Apollo.GetString("CRB_Average"),
	[Item.CodeEnumItemQuality.Good] 			= Apollo.GetString("CRB_Good"),
	[Item.CodeEnumItemQuality.Excellent] 		= Apollo.GetString("CRB_Excellent"),
	[Item.CodeEnumItemQuality.Superb] 			= Apollo.GetString("CRB_Superb"),
	[Item.CodeEnumItemQuality.Legendary] 		= Apollo.GetString("CRB_Legendary"),
	[Item.CodeEnumItemQuality.Artifact]	 		= Apollo.GetString("CRB_Artifact")
}

local ktRowSizeIndexToPixels =
{
	[1] = 21, -- Previously 19
	[2] = 23,
	[3] = 25,
	[4] = 27,
	[5] = 30,
	[6] = 33,
	[7] = 36,
	[8] = 39,
	[9] = 42,
}

local ktUpdateSpeedToSeconds =
{
	[1] = 0.1,
	[2] = 0.25,
	[3] = 0.5,
	[4] = 0.75,
	[5] = 1,
	[6] = 2,
	[7] = 3,
	[8] = 4,
	[9] = 5,
}

local knNumColumnsMax = 5
local knReadyCheckTimeout = 16 -- in seconds
local ktGeneralCategories = {Apollo.GetString("RaidFrame_Members")}
local ktRoleCategoriesToUse = {Apollo.GetString("RaidFrame_Tanks"), Apollo.GetString("RaidFrame_Healers"), Apollo.GetString("RaidFrame_DPS")}

local knDirtyNone = 0
local knDirtyLootRules = bit32.lshift(1, 0)
local knDirtyMembers = bit32.lshift(1, 1)
local knDirtyGeneral = bit32.lshift(1, 2)
local knDirtyResize = bit32.lshift(1, 3)

local knSaveVersion = 6

function RaidFrameBase:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RaidFrameBase:Init()
    Apollo.RegisterAddon(self)
end

function RaidFrameBase:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("RaidFrameBase.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function RaidFrameBase:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSave =
	{
		nSaveVersion 			= knSaveVersion,
		bShowLeaderIcons		= self.tSettings.bShowLeaderIcons,
		bShowClassIcons			= self.tSettings.bShowClassIcons,
		bShowMarkIcons			= self.tSettings.bShowMarkIcons,
		bShowManaBar			= self.tSettings.bShowManaBar,
		bShowFixedShields		= self.tSettings.bShowFixedShields,
		bShowNames				= self.tSettings.bShowNames,
		bLockInCombat			= self.tSettings.bLockInCombat,
		nRowSize				= self.tSettings.nRowSize,
		nNumColumns				= self.tSettings.nNumColumns,
		nUpdateSpeed			= self.tSettings.nUpdateSpeed,

		bIsLocked				= self.tSettings.bIsLocked,
	}
	return tSave
end

function RaidFrameBase:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	-- Defaults
	local tDefaults =
	{
		["bShowLeaderIcons"]		= true,
		["bShowClassIcons"]			= false,
		["bShowMarkIcons"]			= false,
		["bShowManaBar"]			= false,
		["bShowFixedShields"]		= false,
		["bShowCategories"]			= true,
		["bShowNames"]				= true,
		["bLockInCombat"]			= true,
		["nRowSize"]				= 2,
		["nNumColumns"]				= 1,
		["nUpdateSpeed"]			= 1,

		["bIsLocked"]				= false,
	}

	for strName, oDefault in pairs(tDefaults) do
		if tSavedData[strName] == nil then
			tSavedData[strName] = oDefault
		end
	end

	if self.tSettings == nil then
		self.tSettings = {}
	end

	-- Load Settings
	self.tSettings.bShowLeaderIcons 		= tSavedData.bShowLeaderIcons
	self.tSettings.bShowClassIcons 			= tSavedData.bShowClassIcons
	self.tSettings.bShowMarkIcons 			= tSavedData.bShowMarkIcons
	self.tSettings.bShowManaBar 			= tSavedData.bShowManaBar
	self.tSettings.bShowFixedShields 		= tSavedData.bShowFixedShields
	self.tSettings.bShowCategories 			= tSavedData.bShowCategories
	self.tSettings.bShowNames 				= tSavedData.bShowNames
	self.tSettings.bLockInCombat 			= tSavedData.bLockInCombat
	self.tSettings.nRowSize 				= tSavedData.nRowSize
	self.tSettings.nNumColumns 				= tSavedData.nNumColumns
	self.tSettings.nUpdateSpeed 			= tSavedData.nUpdateSpeed

	self.tSettings.bIsLocked 				= tSavedData.bIsLocked
end

function RaidFrameBase:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("CharacterCreated", 						"OnCharacterCreated", self)
	Apollo.RegisterEventHandler("GenericEvent_Raid_ToggleRaidUnTear", 		"OnRaidUnTearOff", self)
	Apollo.RegisterEventHandler("GenericEvent_Raid_UncheckMasterLoot", 		"OnUncheckMasterLoot", self)
	Apollo.RegisterEventHandler("GenericEvent_Raid_UncheckLeaderOptions", 	"OnUncheckLeaderOptions", self)
	Apollo.RegisterEventHandler("WindowManagementReady", 					"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("ChangeWorld", 								"OnChangeWorld", self)
	Apollo.RegisterEventHandler("UnitCreated", 								"OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed", 							"OnUnitDestroyed", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 						"OnEnteredCombat", self)
	Apollo.RegisterEventHandler("Group_Updated", 							"OnGroup_Updated", self)
	Apollo.RegisterEventHandler("Group_Join", 								"OnGroup_Join", self)
	Apollo.RegisterEventHandler("Group_Left", 								"OnGroup_Left", self)
	Apollo.RegisterEventHandler("Group_Add",								"OnGroup_Add", self)
	Apollo.RegisterEventHandler("Group_Remove",								"OnGroup_Remove", self) -- Kicked, or someone else leaves (yourself leaving is Group_Leave)
	Apollo.RegisterEventHandler("Group_MemberFlagsChanged",					"OnGroup_MemberFlagsChanged", self)
	Apollo.RegisterEventHandler("Group_FlagsChanged",						"OnGroup_FlagsChanged", self)
	Apollo.RegisterEventHandler("Group_LootRulesChanged",					"OnGroup_LootRulesChanged", self)
	Apollo.RegisterEventHandler("MasterLootUpdate",							"OnMasterLootUpdate", 	self)

	self.timerRaidBaseTimer = ApolloTimer.Create(ktUpdateSpeedToSeconds[self.tSettings and self.tSettings.nUpdateSpeed or 1], true, "OnRaidFrameBaseTimer", self)
	self.timerResizeTimer = ApolloTimer.Create(0.2, true, "ResizeAllFrames", self)

	Apollo.RegisterTimerHandler("RaidFrame_MinuteTimer", 					"OnRaidFrame_MinuteTimer", self)
	Apollo.CreateTimer("RaidFrame_MinuteTimer", 60, true)

	Apollo.RegisterTimerHandler("ReadyCheckTimeout", 						"OnReadyCheckTimeout", self)
	Apollo.CreateTimer("ReadyCheckTimeout", knReadyCheckTimeout, false)
	Apollo.StopTimer("ReadyCheckTimeout")

	Apollo.RegisterTimerHandler("RaidFrameBase_ResizeThrottle",				"OnRaidFrameBase_ResizeThrottle", self) -- Resize throttle
	Apollo.CreateTimer("RaidFrameBase_ResizeThrottle", 0.5, false)
	Apollo.StopTimer("RaidFrameBase_ResizeThrottle")

	Apollo.RegisterTimerHandler("RaidFrameBase_UnitUpdateThrottle",			"OnRaidFrameBase_UnitUpdateThrottle", self) -- Unit Combat / Range throttle
	Apollo.CreateTimer("RaidFrameBase_UnitUpdateThrottle", 2, false)
	Apollo.StopTimer("RaidFrameBase_UnitUpdateThrottle")

	Apollo.RegisterTimerHandler("RaidFrameBase_GroupUpdatedThrottle",		"OnRaidFrameBase_GroupUpdatedThrottle", self) -- Group Updated
	Apollo.CreateTimer("RaidFrameBase_GroupUpdatedThrottle", 30, false)
	Apollo.StopTimer("RaidFrameBase_GroupUpdatedThrottle")

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "RaidFrameBaseForm", "FixedHudStratum", self)

	self.wndRaidConfigureBtn = self.wndMain:FindChild("RaidConfigureBtn")
	self.wndRaidCategoryContainer = self.wndMain:FindChild("RaidCategoryContainer")
	self.wndRaidTitle = self.wndMain:FindChild("RaidTitle")
	self.wndRaidWrongInstance = self.wndMain:FindChild("RaidWrongInstance")
	self.wndRaidMasterLootIconOnly = self.wndMain:FindChild("RaidMasterLootIconOnly")
	self.wndRaidLeaderOptionsBtn = self.wndMain:FindChild("RaidLeaderOptionsBtn")
	self.wndRaidMasterLootBtn = self.wndMain:FindChild("RaidMasterLootBtn")
	self.wndGroupBagBtn = self.wndMain:FindChild("GroupBagBtn")
	self.wndStartReadyCheckBtn = self.wndMain:FindChild("RaidOptions:SelfConfigReadyCheckLabel:StartReadyCheckBtn")
	self.wndReadyCheckMessageEditBox = self.wndMain:FindChild("RaidOptions:SelfConfigReadyCheckLabel:ReadyCheckMessageEditBox")

	self.wndRaidConfigureBtn:AttachWindow(self.wndMain:FindChild("RaidOptions"))
	self.wndMain:Show(false, true)

	-- Settings
	if not self.tSettings then
		self:OnRestore(nil, { nSaveVersion = knSaveVersion })
	end

	local wndRaidOptions = self.wndMain:FindChild("RaidOptions:SelfConfigRaidCustomizeOptions")
	wndRaidOptions:FindChild("RaidCustomizeLeaderIcons"):SetCheck(self.tSettings.bShowLeaderIcons)
	wndRaidOptions:FindChild("RaidCustomizeClassIcons"):SetCheck(self.tSettings.bShowClassIcons)
	wndRaidOptions:FindChild("RaidCustomizeMarkIcons"):SetCheck(self.tSettings.bShowMarkIcons)
	wndRaidOptions:FindChild("RaidCustomizeManaBar"):SetCheck(self.tSettings.bShowManaBar)
	wndRaidOptions:FindChild("RaidCustomizeFixedShields"):SetCheck(self.tSettings.bShowFixedShields)
	wndRaidOptions:FindChild("RaidCustomizeCategories"):SetCheck(self.tSettings.bShowCategories)
	wndRaidOptions:FindChild("RaidCustomizeShowNames"):SetCheck(self.tSettings.bShowNames)
	wndRaidOptions:FindChild("RaidCustomizeLockInCombat"):SetCheck(self.tSettings.bLockInCombat)

	self.wndRaidCustomizeNumColAdd = wndRaidOptions:FindChild("RaidCustomizeNumColAdd")
	self.wndRaidCustomizeNumColSub = wndRaidOptions:FindChild("RaidCustomizeNumColSub")
	self.wndRaidCustomizeNumColValue = wndRaidOptions:FindChild("RaidCustomizeNumColValue")
	self.wndRaidCustomizeRowSizeSub = wndRaidOptions:FindChild("RaidCustomizeRowSizeSub")
	self.wndRaidCustomizeRowSizeAdd = wndRaidOptions:FindChild("RaidCustomizeRowSizeAdd")
	self.wndRaidCustomizeRowSizeValue = wndRaidOptions:FindChild("RaidCustomizeRowSizeValue")
	self.wndRaidCustomizeSpeedSub = wndRaidOptions:FindChild("RaidCustomizeSpeedSub")
	self.wndRaidCustomizeSpeedAdd = wndRaidOptions:FindChild("RaidCustomizeSpeedAdd")
	self.wndRaidCustomizeSpeedValue = wndRaidOptions:FindChild("RaidCustomizeSpeedValue")
	self.wndRaidLockFrameBtn = self.wndMain:FindChild("RaidLockFrameBtn")

	-- TODO Refactor
	self.nRowSize					= self.tSettings.nRowSize
	self.nNumColumns 				= self.tSettings.nNumColumns
	self.nUpdateSpeed 				= self.tSettings.nUpdateSpeed
	self:HelperUpdateSettings()

	-- Initialize
	self.nDirtyFlag 				= 0
	self.kstrMyName 				= ""
	self.nHealthWarn 				= 0.4
	self.nHealthWarn2 				= 0.6
	self.bThrottleResize	 		= false
	self.bThrottleGroupUpdate 		= false
	self.bThrottleUnitUpdate 		= false
	self.bSwapToTwoColsOnce 		= false
	self.bTimerRunning 				= false
	self.nPrevMemberCount			= 0
	self.arMemberIndexToWindow 		= {}
	self.nRaidMemberWidth 			= 0

	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "RaidCategory", nil, self)
	self.knWndCategoryHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	self.knWndMainHeight = self.wndMain:GetHeight()

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self:OnCharacterCreated()
	end
end

function RaidFrameBase:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndMain, strName = Apollo.GetString("CRB_Raid") })
end

function RaidFrameBase:OnCharacterCreated()
	self.kstrMyName = GameLib.GetPlayerUnit():GetName()

	self:UpdateLootRules()
	self:BuildAllFrames()
	self:ResizeAllFrames()
end

-----------------------------------------------------------------------------------------------
-- Main Timer
-----------------------------------------------------------------------------------------------

function RaidFrameBase:OnRaidFrameBaseTimer()
	if not GroupLib.InRaid() then
		if self.wndMain and self.wndMain:IsValid() then
			self.wndMain:Show(false)
		end
		return
	end

	if not self.wndMain:IsShown() then
		self:OnMasterLootUpdate()
		self.wndMain:Show(true)
	end

	if self.nDirtyFlag > knDirtyNone then
		if bit32.btest(self.nDirtyFlag, knDirtyGeneral) then -- Rebuild everything
			self:BuildAllFrames()
		elseif bit32.btest(self.nDirtyFlag, knDirtyMembers) then -- Fully update all members
			for idx, tRaidMember in pairs(self.arMemberIndexToWindow) do
				self:UpdateSpecificMember(tRaidMember, idx, GroupLib.GetGroupMember(idx), self.nPrevMemberCount)
			end
		else -- Fast update all members
			self:UpdateAllMembers()
		end

		if bit32.btest(self.nDirtyFlag, knDirtyLootRules) then
			self:UpdateLootRules()
		end
	else -- Fast update all members
		self:UpdateAllMembers()
	end

	self.nDirtyFlag = knDirtyNone
end

-----------------------------------------------------------------------------------------------
-- Main Draw Methods
-----------------------------------------------------------------------------------------------

function RaidFrameBase:OnGroup_Join()
	if not GroupLib.InRaid() then return end
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyGeneral)
end

function RaidFrameBase:OnGroup_Add(strName)
	if not GroupLib.InRaid() then return end
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyGeneral)
end

function RaidFrameBase:OnGroup_Remove()
	if not GroupLib.InRaid() then return end
	self:DestroyMemberWindows(self.nPrevMemberCount)
	self.nPrevMemberCount = self.nPrevMemberCount - 1
end

function RaidFrameBase:OnGroup_Left()
	if not GroupLib.InRaid() then return end
	self:DestroyMemberWindows(self.nPrevMemberCount)
	self.nPrevMemberCount = self.nPrevMemberCount - 1
end

function RaidFrameBase:OnGroup_MemberFlagsChanged(nMemberIdx, bFromPromotion, tChangedFlags)
	if not GroupLib.InRaid() then return end
	if not tChangedFlags or not tChangedFlags.bHasSetReady then -- Ready Check is in a different add-on, so ignore for this one now
		self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyGeneral)
	end
end

function RaidFrameBase:OnGroup_LootRulesChanged()
	if not GroupLib.InRaid() then return end
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyLootRules)
end

function RaidFrameBase:OnGroup_FlagsChanged()
	if not GroupLib.InRaid() then return end
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyGeneral)
end

function RaidFrameBase:OnEnteredCombat(unitArg, bInCombat)
	if not self.bThrottleUnitUpdate and self.tSettings.bLockInCombat then
		if GroupLib.InRaid() and self.wndMain and self.wndMain:IsValid() and self.wndMain:IsVisible() and unitArg == GameLib.GetPlayerUnit() then
			self.tSettings.bIsLocked = bInCombat -- If bLockInCombat then it has control over bIsLocked
			self:UpdateCategoryBtns()
			self:HelperUpdateSettings() -- Will update the frame, movable, sizeable
			self.bThrottleUnitUpdate = true
			Apollo.StartTimer("RaidFrameBase_UnitUpdateThrottle")
		end
	end
end

function RaidFrameBase:OnGroup_Updated()
	if not self.bThrottleGroupUpdate and GroupLib.InRaid() then
		self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers)
		self.bThrottleGroupUpdate = true
		Apollo.StartTimer("RaidFrameBase_GroupUpdatedThrottle")
	end
end

function RaidFrameBase:OnChangeWorld()
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyGeneral)
end

function RaidFrameBase:OnUnitCreated(unitNew)
	if not self.bThrottleUnitUpdate and unitNew and unitNew:IsInYourGroup() then
		self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers)
		self.bThrottleUnitUpdate = true
		Apollo.StartTimer("RaidFrameBase_UnitUpdateThrottle")
	end
end

function RaidFrameBase:OnUnitDestroyed(unitOld)
	if not self.bThrottleUnitUpdate and unitOld and unitOld:IsInYourGroup() then
		self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers)
		self.bThrottleUnitUpdate = true
		Apollo.StartTimer("RaidFrameBase_UnitUpdateThrottle")
	end
end

function RaidFrameBase:OnRaidFrameBase_UnitUpdateThrottle()
	Apollo.StopTimer("RaidFrameBase_UnitUpdateThrottle")
	self.bThrottleUnitUpdate = false
end

function RaidFrameBase:OnRaidFrameBase_GroupUpdatedThrottle()
	Apollo.StopTimer("RaidFrameBase_UnitUpdateThrottle")
	self.bThrottleGroupUpdate = false
end

function RaidFrameBase:BuildAllFrames()
	local nGroupMemberCount = GroupLib.GetMemberCount()
	if nGroupMemberCount == 0 then
		self:OnLeaveBtn()
		return
	elseif not self.bSwapToTwoColsOnce and nGroupMemberCount > 20 then
		self.bSwapToTwoColsOnce = true
		self:OnRaidCustomizeNumColAdd(self.wndRaidCustomizeNumColAdd, self.wndRaidCustomizeNumColAdd) -- TODO HACK
	end

	if nGroupMemberCount ~= self.nPrevMemberCount then
		if nGroupMemberCount < self.nPrevMemberCount then
			for nRemoveMemberIdx = nGroupMemberCount + 1, self.nPrevMemberCount do
				self:DestroyMemberWindows(nRemoveMemberIdx)
			end
		end
		self.nPrevMemberCount = nGroupMemberCount
	end

	local tMemberList = {}
	for idx = 1, nGroupMemberCount do
		tMemberList[idx] = {idx, GroupLib.GetGroupMember(idx)}
	end

	local tCategoriesToUse = ktGeneralCategories
	if self.tSettings.bShowCategories then
		tCategoriesToUse = ktRoleCategoriesToUse
	end

	local nInvalidOrDeadMembers = 0
	for idx, tCurrMemberList in pairs(tMemberList) do
		local tMemberData = tCurrMemberList[2]
		if not tMemberData.bIsOnline or tMemberData.nHealthMax == 0 or tMemberData.nHealth == 0 then
			nInvalidOrDeadMembers = nInvalidOrDeadMembers + 1
		end
	end

	self.wndRaidCategoryContainer:DestroyChildren()
	for key, strCurrCategory in pairs(tCategoriesToUse) do
		local tCategory = self:FactoryCategoryWindow(self.wndRaidCategoryContainer, strCurrCategory)
		local wndCategory = tCategory.wnd
		local wndRaidCategoryBtn = tCategory.wndRaidCategoryBtn
		local wndRaidCategoryName = tCategory.wndRaidCategoryName
		local wndRaidCategoryItems = tCategory.wndRaidCategoryItems

		wndRaidCategoryBtn:Show(not self.tSettings.bIsLocked)
		if wndRaidCategoryName:GetText() == "" then
			wndRaidCategoryName:SetText(" " .. strCurrCategory)
		end

		if wndRaidCategoryBtn:IsEnabled() and not wndRaidCategoryBtn:IsChecked() then
			for idx, tCurrMemberList in pairs(tMemberList) do
				self:UpdateMemberFrame(tCategory, tCurrMemberList, strCurrCategory)
			end
		end

		if wndRaidCategoryBtn:IsEnabled() then
			wndCategory:Show(wndRaidCategoryBtn:IsChecked() or next(wndRaidCategoryItems:GetChildren()) ~= nil)
		else
			wndCategory:Show(true)
		end
	end
	self.wndRaidTitle:SetText(String_GetWeaselString(Apollo.GetString("RaidFrame_MemberCount"), nGroupMemberCount - nInvalidOrDeadMembers, nGroupMemberCount))

	local bInInstanceSync = GroupLib.CanGotoGroupInstance()
	self.wndRaidTitle:Show(not bInInstanceSync)
	self.wndRaidWrongInstance:Show(bInInstanceSync)
end

function RaidFrameBase:UpdateLootRules()
	local tLootRules = GroupLib.GetLootRules()
	local strThresholdQuality = ktItemQualityToStr[tLootRules.eThresholdQuality]
	local strTooltip = string.format("<P Font=\"CRB_InterfaceSmall_O\">%s</P><P Font=\"CRB_InterfaceSmall_O\">%s</P><P Font=\"CRB_InterfaceSmall_O\">%s</P>",
						Apollo.GetString("RaidFrame_LootRules"),
						String_GetWeaselString(Apollo.GetString("RaidFrame_UnderThreshold"), strThresholdQuality, Apollo.GetString(ktLootModeToString[tLootRules.eNormalRule])),
						String_GetWeaselString(Apollo.GetString("RaidFrame_ThresholdAndAbove"), strThresholdQuality, Apollo.GetString(ktLootModeToString[tLootRules.eThresholdRule])))
	self.wndRaidMasterLootIconOnly:SetTooltip(strTooltip)
end

function RaidFrameBase:UpdateMemberFrame(tCategory, tCurrMemberList, strCategory)
	local wndCategory = tCategory.wnd
	local wndRaidCategoryItems = tCategory.wndRaidCategoryItems

	local nCodeIdx = tCurrMemberList[1] -- Since actual lua index can change
	local tMemberData = tCurrMemberList[2]
	if tMemberData and self:HelperVerifyMemberCategory(strCategory, tMemberData) then
		local nGroupMemberCount = GroupLib.GetMemberCount()
		local tRaidMember = self:FactoryMemberWindow(wndRaidCategoryItems, nCodeIdx)
		self:UpdateSpecificMember(tRaidMember, nCodeIdx, tMemberData, nGroupMemberCount)
		self.arMemberIndexToWindow[nCodeIdx] = tRaidMember

		-- Me, Self Config at top right
		if tMemberData.strCharacterName == self.kstrMyName then -- TODO better comparison
			self:UpdateRaidOptions(nCodeIdx, tMemberData)
			self.wndRaidLeaderOptionsBtn:Show(tMemberData.bIsLeader or tMemberData.bRaidAssistant)
			self.wndRaidMasterLootIconOnly:Show(not tMemberData.bIsLeader)
			self.wndRaidMasterLootBtn:Show(tMemberData.bIsLeader)
		end
	end
end

function RaidFrameBase:UpdateAllMembers()
	local nGroupMemberCount = GroupLib.GetMemberCount()
	local nInvalidOrDeadMembers = 0

	for idx, tRaidMember in pairs(self.arMemberIndexToWindow) do
		-- HP and Shields
		local tMemberData = GroupLib.GetGroupMember(idx)
		local unitCurr = GroupLib.GetUnitForGroupMember(idx)
		if unitCurr then
			self:DoHPAndShieldResizing(tRaidMember, unitCurr)
		end

		if not tMemberData.bIsOnline or tMemberData.nHealthMax == 0 or tMemberData.nHealth == 0 then
			nInvalidOrDeadMembers = nInvalidOrDeadMembers + 1
		end
	end

	self.wndRaidTitle:SetText(String_GetWeaselString(Apollo.GetString("RaidFrame_MemberCount"), nGroupMemberCount - nInvalidOrDeadMembers, nGroupMemberCount))
end

local kfnSortCategoryMembers = function(a, b)
	return a:GetData().strKey < b:GetData().strKey
end

function RaidFrameBase:UpdateCategoryBtns()
	for idx, wndCategory in pairs(self.wndRaidCategoryContainer:GetChildren()) do
		local tCategory = wndCategory:GetData()
		tCategory.wndRaidCategoryBtn:Show(not self.tSettings.bIsLocked)
	end
end

function RaidFrameBase:ResizeAllFrames()
	-- Calculate these outside the loop, as its the same for entry
	self.nRaidMemberWidth = (self.wndMain:GetWidth() - 22) / self.nNumColumns

	-- Now update each member
	local nLeft, nTop, nRight, nBottom
	for key, wndCategory in pairs(self.wndRaidCategoryContainer:GetChildren()) do
		local tCategory = wndCategory:GetData()
		local wndRaidCategoryItems = tCategory.wndRaidCategoryItems
		for key2, wndRaidMember in pairs(wndRaidCategoryItems:GetChildren()) do
			self:ResizeMemberFrame(wndRaidMember)
		end

		wndRaidCategoryItems:ArrangeChildrenTiles(0, kfnSortCategoryMembers)
		nLeft, nTop, nRight, nBottom = wndCategory:GetAnchorOffsets()
		local nChildrenHeight = 0
		if wndRaidCategoryItems:IsShown() then
			nChildrenHeight = math.ceil(#wndRaidCategoryItems:GetChildren() / self.nNumColumns) * ktRowSizeIndexToPixels[self.nRowSize]
		end
		wndCategory:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nChildrenHeight + self.knWndCategoryHeight)
	end

	-- Lock Max Height
	nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + math.max(self.wndRaidCategoryContainer:ArrangeChildrenVert(0) + 58, self.knWndMainHeight))
	self.wndMain:SetSizingMinimum(175, self.wndMain:GetHeight())
	self.wndMain:SetSizingMaximum(1000, self.wndMain:GetHeight())
end

function RaidFrameBase:ResizeMemberFrame(wndRaidMember)
	local tRaidMember = wndRaidMember:GetData()
	local nLeft, nTop, nRight, nBottom = wndRaidMember:GetAnchorOffsets()
	wndRaidMember:SetAnchorOffsets(nLeft, nTop, nLeft + self.nRaidMemberWidth, nTop + ktRowSizeIndexToPixels[self.nRowSize])
	wndRaidMember:ArrangeChildrenHorz(0)

	-- Button Offsets (from tear off button)
	local nLeftOffset = 0
	if tRaidMember.wndRaidMemberIsLeader:IsShown() then
		nLeftOffset = nLeftOffset + 22
	end
	if tRaidMember.wndRaidMemberClassIcon:IsShown() then
		nLeftOffset = nLeftOffset + 16
	end
	if tRaidMember.wndRaidMemberMarkIcon:IsShown() then
		nLeftOffset = nLeftOffset + 16
	end

	-- Resize Button
	local wndRaidMemberBtn = tRaidMember.wndRaidMemberBtn
	nLeft,nTop,nRight,nBottom = wndRaidMemberBtn:GetAnchorOffsets()
	wndRaidMemberBtn:SetAnchorOffsets(nLeft, nTop, nLeft + self.nRaidMemberWidth - nLeftOffset, nTop + ktRowSizeIndexToPixels[self.nRowSize] + 9)
end

function RaidFrameBase:UpdateRaidOptions(nCodeIdx, tMemberData)
	local wndRaidOptions = self.wndMain:FindChild("RaidOptions")
	local wndRaidOptionsToggles = self.wndMain:FindChild("RaidOptions:SelfConfigSetAsLabel")

	wndRaidOptionsToggles:FindChild("SelfConfigSetAsDPS"):SetData(nCodeIdx)
	wndRaidOptionsToggles:FindChild("SelfConfigSetAsDPS"):SetCheck(tMemberData.bDPS)

	wndRaidOptionsToggles:FindChild("SelfConfigSetAsHealer"):SetData(nCodeIdx)
	wndRaidOptionsToggles:FindChild("SelfConfigSetAsHealer"):SetCheck(tMemberData.bHealer)

	wndRaidOptionsToggles:FindChild("SelfConfigSetAsNormTank"):SetData(nCodeIdx)
	wndRaidOptionsToggles:FindChild("SelfConfigSetAsNormTank"):SetCheck(tMemberData.bTank)

	wndRaidOptionsToggles:Show(not tMemberData.bRoleLocked)
	wndRaidOptions:FindChild("SelfConfigReadyCheckLabel"):Show(tMemberData.bIsLeader or tMemberData.bMainTank or tMemberData.bMainAssist or tMemberData.bRaidAssistant)

	local nLeft, nTop, nRight, nBottom = wndRaidOptions:GetAnchorOffsets()
	wndRaidOptions:SetAnchorOffsets(nLeft, nTop, nRight, nTop + wndRaidOptions:ArrangeChildrenVert(0))
end

function RaidFrameBase:UpdateSpecificMember(tRaidMember, nCodeIdx, tMemberData, nGroupMemberCount)
	if not tRaidMember then
		return
	end

	local wndRaidMember = tRaidMember.wnd
	if not wndRaidMember or not wndRaidMember:IsValid() then
		return
	end

	local unitCurr = GroupLib.GetUnitForGroupMember(nCodeIdx)

	tRaidMember.wndHealthBar:Show(false)
	tRaidMember.wndMaxAbsorbBar:Show(false)
	tRaidMember.wndMaxShieldBar:Show(false)
	tRaidMember.wndCurrShieldBar:Show(false)
	tRaidMember.wndRaidMemberBtn:SetData(tMemberData.nMemberIdx)

	tRaidMember.wndRaidMemberName:Show(self.tSettings.bShowNames)

	local bOutOfRange = not unitCurr
	local bDead = tMemberData.nHealth == 0 and tMemberData.nHealthMax ~= 0
	if not tMemberData.bIsOnline then
		tRaidMember.wndRaidMemberBtn:SetSprite("CRB_Raid:btnRaid_ThinHoloRedBtnNormal")
		tRaidMember.wndRaidMemberName:SetText(String_GetWeaselString(Apollo.GetString("Group_OfflineMember"), tMemberData.strCharacterName))
	elseif bDead then
		tRaidMember.wndRaidMemberBtn:SetSprite("CRB_Raid:btnRaid_ThinHoloRedBtnNormal")
		tRaidMember.wndRaidMemberName:SetText(String_GetWeaselString(Apollo.GetString("Group_DeadMember"), tMemberData.strCharacterName))
	elseif bOutOfRange then
		tRaidMember.wndRaidMemberBtn:SetSprite("")
		tRaidMember.wndRaidMemberName:SetText(String_GetWeaselString(Apollo.GetString("Group_OutOfRange"), tMemberData.strCharacterName))
	else
		tRaidMember.wndRaidMemberBtn:SetSprite("")
		tRaidMember.wndRaidMemberName:SetText(tMemberData.strCharacterName)
	end

	local wndClassIcon = tRaidMember.wndRaidMemberClassIcon
	if self.tSettings.bShowClassIcons then
		wndClassIcon:SetSprite(ktIdToClassSprite[tMemberData.eClassId])
		wndClassIcon:SetTooltip(Apollo.GetString(ktIdToClassTooltip[tMemberData.eClassId]))
	end
	wndClassIcon:Show(self.tSettings.bShowClassIcons)

	local nLeaderIdx = 0
	local bShowLeaderIcon = self.tSettings.bShowLeaderIcons
	local wndLeaderIcon = tRaidMember.wndRaidMemberIsLeader
	if bShowLeaderIcon then
		if tMemberData.bIsLeader then
			nLeaderIdx = 1
		elseif tMemberData.bMainTank then
			nLeaderIdx = 2
		elseif tMemberData.bMainAssist then
			nLeaderIdx = 3
		elseif tMemberData.bRaidAssistant then
			nLeaderIdx = 4
		end
		wndLeaderIcon:SetSprite(ktIdToLeaderSprite[nLeaderIdx])
		wndLeaderIcon:SetTooltip(Apollo.GetString(ktIdToLeaderTooltip[nLeaderIdx]))
	end
	wndLeaderIcon:Show(bShowLeaderIcon and nLeaderIdx ~= 0)

	local nMarkIdx = 0
	local wndMarkIcon = tRaidMember.wndRaidMemberMarkIcon
	if self.tSettings.bShowMarkIcons then
		nMarkIdx = tMemberData.nMarkerId or 0
		wndMarkIcon:SetSprite(kstrRaidMarkerToSprite[nMarkIdx])
	end
	wndMarkIcon:Show(self.tSettings.bShowMarkIcons and nMarkIdx ~= 0)

	-- HP and Shields
	if unitCurr then
		self:DoHPAndShieldResizing(tRaidMember, unitCurr)
	end

	self:ResizeMemberFrame(wndRaidMember)
end

function RaidFrameBase:OnRaidMemberBtnClick(wndHandler, wndControl) -- wndRaidMemberBtn
	if wndHandler ~= wndControl or not wndHandler or not wndHandler:GetData() then
		return
	end

	local unitMember = GroupLib.GetUnitForGroupMember(wndHandler:GetData())
	if unitMember then
		GameLib.SetTargetUnit(unitMember)
	end
end

-----------------------------------------------------------------------------------------------
-- UI
-----------------------------------------------------------------------------------------------

function RaidFrameBase:OnRaidFrame_MinuteTimer()
	if not GroupLib.InRaid() then return end
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers)
end

function RaidFrameBase:OnRaidCategoryBtnToggle(wndHandler, wndControl) -- RaidCategoryBtn
	local tCategory = wndHandler:GetParent():GetData()
	tCategory.wndRaidCategoryItems:Show(not tCategory.wndRaidCategoryItems:IsShown())
end

function RaidFrameBase:OnRaidLeaderOptionsToggle(wndHandler, wndControl) -- RaidLeaderOptionsBtn
	Event_FireGenericEvent("GenericEvent_Raid_ToggleMasterLoot", false)
	Event_FireGenericEvent("GenericEvent_Raid_ToggleLeaderOptions", wndHandler:IsChecked())
end

function RaidFrameBase:OnRaidMasterLootToggle(wndHandler, wndControl) -- RaidMasterLootBtn
	Event_FireGenericEvent("GenericEvent_Raid_ToggleMasterLoot", wndHandler:IsChecked())
	Event_FireGenericEvent("GenericEvent_Raid_ToggleLeaderOptions", false)
end

function RaidFrameBase:OnRaidConfigureToggle(wndHandler, wndControl) -- RaidConfigureBtn
	if wndHandler:IsChecked() then
		Event_FireGenericEvent("GenericEvent_Raid_ToggleMasterLoot", false)
		Event_FireGenericEvent("GenericEvent_Raid_ToggleLeaderOptions", false)
	end

	local bReadyCheckOnCooldown = GroupLib.IsReadyCheckOnCooldown()
	self.wndStartReadyCheckBtn:Enable(not bReadyCheckOnCooldown)
	self.wndReadyCheckMessageEditBox:SetPrompt(bReadyCheckOnCooldown and Apollo.GetString("RaidFrame_ReadyCheckOnCooldown") or Apollo.GetString("RaidFrame_AreYouReady"))
end

function RaidFrameBase:OnLeaveBtn(wndHandler, wndControl)
	self:OnUncheckLeaderOptions()
	self:OnUncheckMasterLoot()
	GroupLib.LeaveGroup()
end

function RaidFrameBase:OnRaidLeaveShowPrompt(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() and self.wndRaidConfigureBtn then
		self.wndRaidConfigureBtn:SetCheck(false)
	end
	self:OnUncheckLeaderOptions()
	self:OnUncheckMasterLoot()
	Apollo.LoadForm(self.xmlDoc, "RaidLeaveYesNo", nil, self)
end

function RaidFrameBase:OnRaidLeaveYes(wndHandler, wndControl)
	wndHandler:GetParent():Destroy()
	self:OnLeaveBtn()
end

function RaidFrameBase:OnRaidLeaveNo(wndHandler, wndControl)
	wndHandler:GetParent():Destroy()
end

function RaidFrameBase:OnUncheckLeaderOptions()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndRaidLeaderOptionsBtn:SetCheck(false)
	end
end

function RaidFrameBase:OnUncheckMasterLoot()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndRaidMasterLootBtn:SetCheck(false)
	end
end

function RaidFrameBase:OnGroupBagBtn()
	Event_FireGenericEvent("GenericEvent_ToggleGroupBag")
end

function RaidFrameBase:OnMasterLootUpdate()
	local tMasterLoot = GameLib.GetMasterLoot()
	local bShowMasterLoot = tMasterLoot and #tMasterLoot > 0
	local nLeft, nTop, nRight, nBottom = self.wndRaidTitle:GetAnchorOffsets()
	self.wndRaidTitle:SetAnchorOffsets(bShowMasterLoot and 40 or 12, nTop, nRight, nBottom)

	self.wndGroupBagBtn:Show(bShowMasterLoot)
end

function RaidFrameBase:OnRaidWrongInstance()
	GroupLib.GotoGroupInstance()
end

-----------------------------------------------------------------------------------------------
-- Ready Check
-----------------------------------------------------------------------------------------------

function RaidFrameBase:OnStartReadyCheckBtn(wndHandler, wndControl) -- StartReadyCheckBtn
	self.wndRaidConfigureBtn:SetFocus() -- To remove out of edit box
	self.wndRaidConfigureBtn:SetCheck(false)

	local strMessage = self.wndReadyCheckMessageEditBox:GetText()
	GroupLib.ReadyCheck(string.len(strMessage) > 0 and strMessage or Apollo.GetString("RaidFrame_AreYouReady")) -- Sanitized in code
end

function RaidFrameBase:OnReadyCheckTimeout()
	local bReadyCheckOnCooldown = GroupLib.IsReadyCheckOnCooldown()
	self.wndStartReadyCheckBtn:Enable(not bReadyCheckOnCooldown)
	self.wndReadyCheckMessageEditBox:SetPrompt(bReadyCheckOnCooldown and Apollo.GetString("RaidFrame_ReadyCheckOnCooldown") or Apollo.GetString("RaidFrame_AreYouReady"))
end

-----------------------------------------------------------------------------------------------
-- Self Config and Settings Customization
-----------------------------------------------------------------------------------------------

function RaidFrameBase:HelperUpdateSettings()
	local wndRaidOptions = self.wndMain:FindChild("RaidOptions:SelfConfigRaidCustomizeOptions")
	self.tSettings.bShowLeaderIcons 		= wndRaidOptions:FindChild("RaidCustomizeLeaderIcons"):IsChecked()
	self.tSettings.bShowClassIcons 			= wndRaidOptions:FindChild("RaidCustomizeClassIcons"):IsChecked()
	self.tSettings.bShowMarkIcons 			= wndRaidOptions:FindChild("RaidCustomizeMarkIcons"):IsChecked()
	self.tSettings.bShowManaBar 			= wndRaidOptions:FindChild("RaidCustomizeManaBar"):IsChecked()
	self.tSettings.bShowFixedShields 		= wndRaidOptions:FindChild("RaidCustomizeFixedShields"):IsChecked()
	self.tSettings.bShowCategories 			= wndRaidOptions:FindChild("RaidCustomizeCategories"):IsChecked()
	self.tSettings.bShowNames 				= wndRaidOptions:FindChild("RaidCustomizeShowNames"):IsChecked()
	self.tSettings.bLockInCombat 			= wndRaidOptions:FindChild("RaidCustomizeLockInCombat"):IsChecked()
	self.tSettings.nRowSize 				= self.nRowSize
	self.tSettings.nNumColumns 				= self.nNumColumns
	self.tSettings.nUpdateSpeed				= self.nUpdateSpeed

	self.wndRaidCustomizeRowSizeSub:Enable(self.tSettings.nRowSize > 1)
	self.wndRaidCustomizeRowSizeAdd:Enable(self.tSettings.nRowSize < #ktRowSizeIndexToPixels)
	self.wndRaidCustomizeRowSizeValue:SetText(self.tSettings.nRowSize)

	self.wndRaidCustomizeNumColSub:Enable(self.tSettings.nNumColumns > 1)
	self.wndRaidCustomizeNumColAdd:Enable(self.tSettings.nNumColumns < knNumColumnsMax)
	self.wndRaidCustomizeNumColValue:SetText(self.tSettings.nNumColumns)

	self.wndRaidCustomizeSpeedSub:Enable(self.tSettings.nUpdateSpeed > 1)
	self.wndRaidCustomizeSpeedAdd:Enable(self.tSettings.nUpdateSpeed < #ktUpdateSpeedToSeconds)
	self.wndRaidCustomizeSpeedValue:SetText(self.tSettings.nUpdateSpeed)

	--self.tSettings.bIsLocked 				= wndRaidOptions:FindChild("RaidLockFrameBtn"):IsChecked() -- GOTCHA: Don't do this, as it can get auto clicked by bLockInCombat
	self.wndRaidLockFrameBtn:SetCheck(self.tSettings.bIsLocked)
	self.wndMain:SetStyle("Sizable", not self.tSettings.bIsLocked)
	self.wndMain:SetStyle("Moveable", not self.tSettings.bIsLocked)
	self.wndMain:SetSprite(self.tSettings.bIsLocked and "sprRaid_BaseNoArrow" or "sprRaid_Base")
end

function RaidFrameBase:OnConfigSetAsDPSToggle(wndHandler, wndControl)
	GroupLib.SetRoleDPS(wndHandler:GetData(), wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameBase:OnConfigSetAsTankToggle(wndHandler, wndControl)
	GroupLib.SetRoleTank(wndHandler:GetData(), wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameBase:OnConfigSetAsHealerToggle(wndHandler, wndControl)
	GroupLib.SetRoleHealer(wndHandler:GetData(), wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameBase:OnRaidCustomizeCategoryCheck(wndHandler, wndControl, eMouseButton)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyGeneral)
	self:HelperUpdateSettings()
end

function RaidFrameBase:OnRaidCustomizeShowNamesCheck(wndHandler, wndControl, eMouseButton)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers)
	self:HelperUpdateSettings()
end

function RaidFrameBase:OnRaidCustomizeDirtyMembers(wndHandler, wndControl, eMouseButton)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers)
	self:HelperUpdateSettings()
end

function RaidFrameBase:OnRaidCustomizeNumColAdd(wndHandler, wndControl) -- RaidCustomizeNumColAdd, and once from bSwapToTwoColsOnce
	self.nNumColumns = self.nNumColumns + 1
	if self.nNumColumns >= knNumColumnsMax then
		self.nNumColumns = knNumColumnsMax
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeNumColSub:Enable(true)
	self.wndRaidCustomizeNumColValue:SetText(self.nNumColumns)
	self:HelperUpdateSettings()
end

function RaidFrameBase:OnRaidCustomizeNumColSub(wndHandler, wndControl) -- RaidCustomizeNumColSub
	self.nNumColumns = self.nNumColumns - 1
	if self.nNumColumns <= 1 then
		self.nNumColumns = 1
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeNumColAdd:Enable(true)
	self.wndRaidCustomizeNumColValue:SetText(self.nNumColumns)
	self:HelperUpdateSettings()
end

function RaidFrameBase:OnRaidCustomizeRowSizeAdd(wndHandler, wndControl) -- RaidCustomizeRowSizeAdd
	self.nRowSize = self.nRowSize + 1
	if self.nRowSize >= #ktRowSizeIndexToPixels then
		self.nRowSize = #ktRowSizeIndexToPixels
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeRowSizeSub:Enable(true)
	self.wndRaidCustomizeRowSizeValue:SetText(self.nRowSize)
	self:HelperUpdateSettings()
end

function RaidFrameBase:OnRaidCustomizeRowSizeSub(wndHandler, wndControl) -- RaidCustomizeRowSizeSub
	self.nRowSize = self.nRowSize - 1
	if self.nRowSize <= 1 then
		self.nRowSize = 1
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeRowSizeAdd:Enable(true)
	self.wndRaidCustomizeRowSizeValue:SetText(self.nRowSize)
	self:HelperUpdateSettings()
end

function RaidFrameBase:OnRaidCustomizeSpeedAdd(wndHandler, wndControl) -- RaidCustomizeSpeedAdd
	self.nUpdateSpeed = self.nUpdateSpeed + 1
	if self.nUpdateSpeed >= #ktUpdateSpeedToSeconds then
		self.nUpdateSpeed = #ktUpdateSpeedToSeconds
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeSpeedSub:Enable(true)
	self.wndRaidCustomizeSpeedValue:SetText(self.nUpdateSpeed)

	self:HelperUpdateRaidUpdateSpeed()
	self:HelperUpdateSettings()
end

function RaidFrameBase:OnRaidCustomizeSpeedSub(wndHandler, wndControl) -- RaidCustomizeSpeedSub
	self.nUpdateSpeed = self.nUpdateSpeed - 1
	if self.nUpdateSpeed <= 1 then
		self.nUpdateSpeed = 1
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeRowSizeAdd:Enable(true)
	self.wndRaidCustomizeRowSizeValue:SetText(self.nUpdateSpeed)

	self:HelperUpdateRaidUpdateSpeed()
	self:HelperUpdateSettings()
end

function RaidFrameBase:HelperUpdateRaidUpdateSpeed()
	self.timerRaidBaseTimer:Stop()
	self.timerRaidBaseTimer = ApolloTimer.Create(ktUpdateSpeedToSeconds[self.nUpdateSpeed], true, "OnRaidFrameBaseTimer", self)
	Event_FireGenericEvent("GenericEvent_SystemChannelMessage", String_GetWeaselString(Apollo.GetString("RaidFrame_UpdateSpeedChanged"), tostring(ktUpdateSpeedToSeconds[self.nUpdateSpeed])))
end

function RaidFrameBase:OnRaidLockFrameBtnToggle(wndHandler, wndControl) -- RaidLockFrameBtn
	self.tSettings.bIsLocked = wndHandler:IsChecked()
	self:HelperUpdateSettings()
	self:UpdateCategoryBtns()
end

-----------------------------------------------------------------------------------------------
-- Clean Up
-----------------------------------------------------------------------------------------------

function RaidFrameBase:DestroyMemberWindows(nMemberIdx)
	local tCategoriesToUse = {Apollo.GetString("RaidFrame_Members")}
	if self.tSettings.bShowCategories then
		tCategoriesToUse = {Apollo.GetString("RaidFrame_Tanks"), Apollo.GetString("RaidFrame_Healers"), Apollo.GetString("RaidFrame_DPS")}
	end

	for key, strCurrCategory in pairs(tCategoriesToUse) do
		local wndCategory = self.wndRaidCategoryContainer:FindChild(strCurrCategory)
		if wndCategory ~= nil then
			local wndMember = wndCategory:FindChild(nMemberIdx)
			if wndMember ~= nil then
				self.arMemberIndexToWindow[nMemberIdx] = nil
				wndMember:Destroy()
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function RaidFrameBase:HelperVerifyMemberCategory(strCurrCategory, tMemberData)
	local bResult = true
	if strCurrCategory == Apollo.GetString("RaidFrame_Tanks") then
		bResult =  tMemberData.bTank
	elseif strCurrCategory == Apollo.GetString("RaidFrame_Healers") then
		bResult = tMemberData.bHealer
	elseif strCurrCategory == Apollo.GetString("RaidFrame_DPS") then
		bResult = not tMemberData.bTank and not tMemberData.bHealer
	end
	return bResult
end

function RaidFrameBase:DoHPAndShieldResizing(tRaidMember, unitPlayer)
	local nHealthCurr = unitPlayer:GetHealth()
	local nHealthMax = unitPlayer:GetMaxHealth()
	local nShieldCurr = unitPlayer:GetShieldCapacity()
	local nShieldMax = unitPlayer:GetShieldCapacityMax()
	local nAbsorbCurr = 0
	local nAbsorbMax = unitPlayer:GetAbsorptionMax()
	if nAbsorbMax > 0 then
		nAbsorbCurr = unitPlayer:GetAbsorptionValue() -- Since it doesn't clear when the buff drops off
	end
	local nTotalMax = nHealthMax + nShieldMax + nAbsorbMax

	-- Bars
	local wndHealthBar = tRaidMember.wndHealthBar
	local wndMaxAbsorb = tRaidMember.wndMaxAbsorbBar
	local wndMaxShield = tRaidMember.wndMaxShieldBar
	wndHealthBar:Show(nHealthCurr > 0 and nHealthMax > 0)
	wndMaxAbsorb:Show(nHealthCurr > 0 and nAbsorbMax > 0)
	wndMaxShield:Show(nHealthCurr > 0 and nShieldMax > 0)

	local wndCurrShieldBar = tRaidMember.wndCurrShieldBar
	wndCurrShieldBar:Show(nHealthCurr > 0 and nShieldMax > 0)
	wndCurrShieldBar:SetMax(nShieldMax)
	wndCurrShieldBar:SetProgress(nShieldCurr)
	wndCurrShieldBar:EnableGlow((wndCurrShieldBar:GetWidth() * nShieldCurr/nShieldMax) > 4)

	local wndCurrAbsorbBar = tRaidMember.wndCurrAbsorbBar
	wndCurrAbsorbBar:SetMax(nAbsorbMax)
	wndCurrAbsorbBar:SetProgress(nAbsorbCurr)
	wndCurrAbsorbBar:EnableGlow((wndCurrAbsorbBar:GetWidth() * nAbsorbCurr/nAbsorbMax) > 4)

	-- Health Bar Color
	if (nHealthCurr / nHealthMax) < self.nHealthWarn then
		wndHealthBar:SetSprite("sprRaid_HealthProgBar_Red")
	elseif (nHealthCurr / nHealthMax) < self.nHealthWarn2 then
		wndHealthBar:SetSprite("sprRaid_HealthProgBar_Orange")
	else
		wndHealthBar:SetSprite("sprRaid_HealthProgBar_Green")
	end

	-- Scaling
	local nArtOffset = 2
	local nWidth = tRaidMember.wndRaidMemberBtn:GetWidth() - 4
	local nPointHealthRight = nWidth * (nHealthCurr / nTotalMax)
	local nPointShieldRight = nWidth * ((nHealthCurr + nShieldMax) / nTotalMax)
	local nPointAbsorbRight = nWidth * ((nHealthCurr + nShieldMax + nAbsorbMax) / nTotalMax)

	local nLeft, nTop, nRight, nBottom = wndHealthBar:GetAnchorOffsets()
	if not self.tSettings.bShowFixedShields then
		wndHealthBar:SetAnchorOffsets(nLeft, nTop, nPointHealthRight, nBottom)
		wndMaxShield:SetAnchorOffsets(nPointHealthRight - nArtOffset, nTop, nPointShieldRight, nBottom)
		wndMaxAbsorb:SetAnchorOffsets(nPointShieldRight - nArtOffset, nTop, nPointAbsorbRight, nBottom)
	elseif nAbsorbMax == 0 then
		wndHealthBar:SetAnchorOffsets(nLeft, nTop, nWidth * 0.9 * nHealthCurr / nHealthMax, nBottom)
		wndMaxShield:SetAnchorOffsets(nWidth * 0.9, nTop, nWidth, nBottom)
	else
		wndHealthBar:SetAnchorOffsets(nLeft, nTop, nWidth * 0.9 * nHealthCurr / nHealthMax, nBottom)
		wndMaxShield:SetAnchorOffsets(nWidth * 0.9, nTop, nWidth, nBottom)
		wndMaxAbsorb:SetAnchorOffsets(nWidth * 0.8, nTop, nWidth * 0.9, nBottom)
	end

	-- Mana Bar
	local nManaCurr = unitPlayer:GetMana()
	local nManaMax = unitPlayer:GetMaxMana() or nManaCurr
	if self.tSettings.bShowManaBar then
		tRaidMember.wndRaidMemberManaBar:SetMax(nManaMax)
		tRaidMember.wndRaidMemberManaBar:SetProgress(nManaCurr)
	end
	tRaidMember.wndRaidMemberManaBar:Show(self.tSettings.bShowManaBar and nManaMax > 0 and nHealthCurr > 0 and nHealthMax > 0)
end

function RaidFrameBase:FactoryMemberWindow(wndParent, strKey)
	if self.cache == nil then
		self.cache = {}
	end

	local tbl = self.cache[strKey]
	if tbl == nil or not tbl.wnd:IsValid() then
		local wndNew = Apollo.LoadForm(self.xmlDoc, "RaidMember", wndParent, self)
		wndNew:SetName(strKey)

		tbl =
		{
			["strKey"] = strKey,
			wnd = wndNew,
			wndHealthBar = wndNew:FindChild("RaidMemberBtn:HealthBar"),
			wndMaxAbsorbBar = wndNew:FindChild("RaidMemberBtn:MaxAbsorbBar"),
			wndCurrAbsorbBar = wndNew:FindChild("RaidMemberBtn:MaxAbsorbBar:CurrAbsorbBar"),
			wndMaxShieldBar = wndNew:FindChild("RaidMemberBtn:MaxShieldBar"),
			wndCurrShieldBar = wndNew:FindChild("RaidMemberBtn:MaxShieldBar:CurrShieldBar"),
			wndRaidMemberBtn = wndNew:FindChild("RaidMemberBtn"),
			wndRaidMemberManaBar = wndNew:FindChild("RaidMemberBtn:RaidMemberManaBar"),
			wndRaidMemberName = wndNew:FindChild("RaidMemberName"),
			wndRaidMemberClassIcon = wndNew:FindChild("RaidMemberClassIcon"),
			wndRaidMemberIsLeader = wndNew:FindChild("RaidMemberIsLeader"),
			wndRaidMemberMarkIcon = wndNew:FindChild("RaidMemberMarkIcon"),
		}
		wndNew:SetData(tbl)
		self.cache[strKey] = tbl

		for strCacheKey, wndCached in pairs(self.cache) do
			if not self.cache[strCacheKey].wnd:IsValid() then
				self.cache[strCacheKey] = nil
			end
		end
	end

	return tbl
end

function RaidFrameBase:FactoryCategoryWindow(wndParent, strKey)
	if self.cache == nil then
		self.cache = {}
	end

	local tbl = self.cache[strKey]
	if tbl == nil or not tbl.wnd:IsValid() then
		local wndNew = Apollo.LoadForm(self.xmlDoc, "RaidCategory", wndParent, self)
		wndNew:SetName(strKey)

		tbl =
		{
			wnd = wndNew,
			wndRaidCategoryBtn = wndNew:FindChild("RaidCategoryBtn"),
			wndRaidCategoryName = wndNew:FindChild("RaidCategoryName"),
			wndRaidCategoryItems = wndNew:FindChild("RaidCategoryItems"),
		}
		wndNew:SetData(tbl)
		self.cache[strKey] = tbl

		for strCacheKey, wndCached in pairs(self.cache) do
			if not self.cache[strCacheKey].wnd:IsValid() then
				self.cache[strCacheKey] = nil
			end
		end
	end

	return tbl
end

local RaidFrameBaseInst = RaidFrameBase:new()
RaidFrameBaseInst:Init()
