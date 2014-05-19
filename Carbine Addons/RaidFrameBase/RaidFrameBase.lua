-------------------------------------------------------------------------------------------
-- Client Lua Script for RaidFrameBase
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "bit32"

local RaidFrameBase = {}

-- TODO: This should be enums (string comparison already fails on esper)
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

local ktRoleNames =
{
	[-1] = "",
	[MatchingGame.Roles.Tank] = Apollo.GetString("RaidFrame_Tanks"),
	[MatchingGame.Roles.Healer] = Apollo.GetString("RaidFrame_Healers"),
	[MatchingGame.Roles.DPS] = Apollo.GetString("RaidFrame_DPS"),
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
	[2] = 28,
	[3] = 33,
	[4] = 38,
	[5] = 42,
}

local ktGeneralCategories = {Apollo.GetString("RaidFrame_Members")}
local ktRoleCategoriesToUse = {Apollo.GetString("RaidFrame_Tanks"), Apollo.GetString("RaidFrame_Healers"), Apollo.GetString("RaidFrame_DPS")}

local knReadyCheckTimeout = 60 -- in seconds

local knSaveVersion = 3

local knDirtyNone = 0
local knDirtyLootRules = bit32.lshift(1, 0)
local knDirtyMembers = bit32.lshift(1, 1)
local knDirtyGeneral = bit32.lshift(1, 2)
local knDirtyResize = bit32.lshift(1, 3)

function RaidFrameBase:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	
	o.arWindowMap = {}
	o.arMemberIndexToWindow = {}
	o.nDirtyFlag = 0

    return o
end

function RaidFrameBase:Init()
    Apollo.RegisterAddon(self)
end

function RaidFrameBase:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local bHasReadyCheck = false
	if self.wndReadyCheckPopup and self.wndReadyCheckPopup:IsValid() then
		bHasReadyCheck = self.wndReadyCheckPopup:IsShown()
	end

	local tSave =
	{
		bReadyCheckShown 		= bHasReadyCheck,
		fReadyCheckStartTime 	= self.fReadyCheckStartTime,
		strReadyCheckInitiator	= self.strReadyCheckInitiator,
		strReadyCheckMessage	= self.strReadyCheckMessage,
		nReadyCheckResponses 	= self.nNumReadyCheckResponses,
		nSaveVersion 			= knSaveVersion,
	}

	return tSave
end

function RaidFrameBase:OnRestore(eType, tSavedData)
	self.tSavedData = tSavedData
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end


	local fDelta = tSavedData.fReadyCheckStartTime and os.clock() - tSavedData.fReadyCheckStartTime or knReadyCheckTimeout
	if fDelta < knReadyCheckTimeout then
		self.nNumReadyCheckResponses = 0
		self.fReadyCheckStartTime = tSavedData.fReadyCheckStartTime

		if tSavedData.bReadyCheckShown then
			if self.nNumReadyCheckResponses >= tSavedData.nReadyCheckResponses then

				self.strReadyCheckInitiator = tSavedData.strReadyCheckInitiator
				self.strReadyCheckMessage = tSavedData.strReadyCheckMessage
			end
		end
		Apollo.CreateTimer("ReadyCheckTimeout", math.ceil(knReadyCheckTimeout - fDelta), false)
	end
end

function RaidFrameBase:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("RaidFrameBase.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function RaidFrameBase:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("CharacterCreated", 						"OnCharacterCreated", self)
	Apollo.RegisterEventHandler("Group_Updated", 							"OnGroup_Updated", self)
	Apollo.RegisterEventHandler("Group_Join", 								"OnGroup_Join", self)
	Apollo.RegisterEventHandler("Group_Left", 								"OnGroup_Left", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 						"OnEnteredCombat", self)
	Apollo.RegisterEventHandler("GenericEvent_Raid_ToggleRaidUnTear", 		"OnRaidUnTearOff", self)
	Apollo.RegisterEventHandler("GenericEvent_Raid_UncheckMasterLoot", 		"OnUncheckMasterLoot", self)
	Apollo.RegisterEventHandler("GenericEvent_Raid_UncheckLeaderOptions", 	"OnUncheckLeaderOptions", self)

	Apollo.RegisterEventHandler("Group_Add",								"OnGroup_Add", self)
	Apollo.RegisterEventHandler("Group_Remove",								"OnGroup_Remove", self) -- Kicked, or someone else leaves (yourself leaving is Group_Leave)
	Apollo.RegisterEventHandler("Group_ReadyCheck",							"OnGroup_ReadyCheck", self)
	Apollo.RegisterEventHandler("Group_MemberFlagsChanged",					"OnGroup_MemberFlagsChanged", self)
	Apollo.RegisterEventHandler("Group_FlagsChanged",						"OnGroup_FlagsChanged", self)
	Apollo.RegisterEventHandler("Group_LootRulesChanged",					"OnGroup_LootRulesChanged", self)
	Apollo.RegisterEventHandler("TargetUnitChanged", 						"OnTargetUnitChanged", self)
	Apollo.RegisterEventHandler("MasterLootUpdate",							"OnMasterLootUpdate", 	self)

	Apollo.RegisterTimerHandler("ReadyCheckTimeout", 						"OnReadyCheckTimeout", self)
	Apollo.RegisterEventHandler("VarChange_FrameCount", 					"OnRaidFrameBaseTimer", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "RaidFrameBaseForm", "FixedHudStratum", self)
    self.wndMain:FindChild("RaidConfigureBtn"):AttachWindow(self.wndMain:FindChild("RaidOptions"))

	self.wndRaidCategoryContainer = self.wndMain:FindChild("RaidCategoryContainer")
	self.wndRaidTitle = self.wndMain:FindChild("RaidTitle")
	self.wndRaidWrongInstance = self.wndMain:FindChild("RaidWrongInstance")
	self.wndRaidMasterLootIconOnly = self.wndMain:FindChild("RaidMasterLootIconOnly")
	self.wndRaidLeaderOptionsBtn = self.wndMain:FindChild("RaidLeaderOptionsBtn")
	self.wndRaidMasterLootBtn = self.wndMain:FindChild("RaidMasterLootBtn")
	self.wndGroupBagBtn = self.wndMain:FindChild("GroupBagBtn")
	self.wndRaidLockFrameBtn = self.wndMain:FindChild("RaidLockFrameBtn")
	
	local wndRaidOptions = self.wndMain:FindChild("RaidOptions:SelfConfigRaidCustomizeOptions")
	self.wndRaidCustomizeClassIcons = wndRaidOptions:FindChild("RaidCustomizeClassIcons")
	self.wndRaidCustomizeShowNames = wndRaidOptions:FindChild("RaidCustomizeShowNames")
	self.wndRaidCustomizeLeaderIcons = wndRaidOptions:FindChild("RaidCustomizeLeaderIcons")
	self.wndRaidCustomizeRoleIcons = wndRaidOptions:FindChild("RaidCustomizeRoleIcons")
	self.wndRaidCustomizeMarkIcons = wndRaidOptions:FindChild("RaidCustomizeMarkIcons")
	self.wndRaidCustomizeManaBar = wndRaidOptions:FindChild("RaidCustomizeManaBar")
	self.wndRaidCustomizeCategories = wndRaidOptions:FindChild("RaidCustomizeCategories")
	self.wndRaidCustomizeClassIcons = wndRaidOptions:FindChild("RaidCustomizeClassIcons")
	self.wndRaidCustomizeFixedShields = wndRaidOptions:FindChild("RaidCustomizeFixedShields")
	self.wndRaidCustomizeNumColAdd = wndRaidOptions:FindChild("RaidCustomizeNumColAdd")
	self.wndRaidCustomizeNumColSub = self.wndMain:FindChild("RaidCustomizeNumColSub")
	self.wndRaidCustomizeNumColValue = self.wndMain:FindChild("RaidCustomizeNumColValue")
	self.wndRaidCustomizeRowSizeSub = self.wndMain:FindChild("RaidCustomizeRowSizeSub")
	self.wndRaidCustomizeRowSizeAdd = self.wndMain:FindChild("RaidCustomizeRowSizeAdd")
	self.wndRaidCustomizeRowSizeValue = self.wndMain:FindChild("RaidCustomizeRowSizeValue")

	wndRaidOptions:FindChild("RaidCustomizeLockInCombat"):SetCheck(true)
	wndRaidOptions:FindChild("RaidCustomizeLeaderIcons"):SetCheck(true)
	wndRaidOptions:FindChild("RaidCustomizeCategories"):SetCheck(true)
	wndRaidOptions:FindChild("RaidCustomizeShowNames"):SetCheck(true)
	self.wndRaidCustomizeRowSizeSub:Enable(false) -- as self.nRowSize == 1 at default
	self.wndRaidCustomizeNumColSub:Enable(false) -- as self.nNumColumns == 1 at default
	self.wndMain:Show(false)
	
	self.nRowSize					= 1
	self.nNumColumns 				= 1
	self.kstrMyName 				= ""
	self.nHealthWarn 				= 0.4
	self.nHealthWarn2 				= 0.6
	self.tTearOffMemberIDs 			= {}

	if self.strReadyCheckInitiator and self.strReadyCheckMessage then
		local strMessage = String_GetWeaselString(Apollo.GetString("RaidFrame_ReadyCheckStarted"), self.strReadyCheckInitiator) .. "\n" .. self.strReadyCheckMessage
		self.wndReadyCheckPopup = Apollo.LoadForm(self.xmlDoc, "RaidReadyCheck", nil, self)
		self.wndReadyCheckPopup:SetData(wndReadyCheckPopup)
		self.wndReadyCheckPopup:FindChild("ReadyCheckNoBtn"):SetData(wndReadyCheckPopup)
		self.wndReadyCheckPopup:FindChild("ReadyCheckYesBtn"):SetData(wndReadyCheckPopup)
		self.wndReadyCheckPopup:FindChild("ReadyCheckCloseBtn"):SetData(wndReadyCheckPopup)
		self.wndReadyCheckPopup:FindChild("ReadyCheckMessage"):SetText(strMessage)
	else
		self.wndReadyCheckPopup 	= nil
	end
	
	self.bSwapToTwoColsOnce 		= false
	self.bTimerRunning 				= false
	self.nNumReadyCheckResponses 	= -1 -- -1 means no check, 0 and higher means there is a check
	self.nPrevMemberCount			= 0

	self:UpdateOffsets()
	
	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "RaidCategory", nil, self)
	self.knWndCategoryHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()

	self.knWndMainHeight = self.wndMain:GetHeight()

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self:OnCharacterCreated()
	end

end

function RaidFrameBase:OnCharacterCreated()
	local unitPlayer = GameLib.GetPlayerUnit()
	self.kstrMyName = unitPlayer:GetName()
	self.unitTarget = GameLib.GetTargetUnit()
	
	self:BuildAllFrames()
	self:ResizeAllFrames()
end

function RaidFrameBase:OnRaidFrameBaseTimer()
	if not GroupLib.InRaid() then
		if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsShown() then
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
			self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyResize)
		elseif bit32.btest(self.nDirtyFlag, knDirtyMembers) then -- Fully update all members
			for idx, tRaidMember in pairs(self.arMemberIndexToWindow) do
				self:UpdateSpecificMember(tRaidMember, idx, GroupLib.GetGroupMember(idx), self.nPrevMemberCount, bFrameLocked)
			end
		else -- Fast update all members
			self:UpdateAllMembers()
		end
		
		if bit32.btest(self.nDirtyFlag, knDirtyLootRules) then
			self:UpdateLootRules()
		end
		
		if bit32.btest(self.nDirtyFlag, knDirtyResize) then
			self:ResizeAllFrames()
			if self.nNumColumns then -- This is terrible
				self:ResizeAllFrames()
			end
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

	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers, knDirtyResize)
end

function RaidFrameBase:OnGroup_Left()
	if not GroupLib.InRaid() then return end

	self:DestroyMemberWindows(self.nPrevMemberCount)
	self.nPrevMemberCount = self.nPrevMemberCount - 1
	
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers, knDirtyResize)
end

function RaidFrameBase:OnGroup_Updated()
	if not GroupLib.InRaid() then return end
	--self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyGeneral)
end

function RaidFrameBase:OnGroup_MemberFlagsChanged(nMemberIdx, bFromPromotion, tChangedFlags)
	if not GroupLib.InRaid() then return end
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyGeneral)
end

function RaidFrameBase:OnGroup_LootRulesChanged()
	if not GroupLib.InRaid() then return end
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyLootRules)
end

function RaidFrameBase:OnGroup_FlagsChanged()
	if not GroupLib.InRaid() then return end
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyGeneral)
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
			for nRemoveMemberIdx=nGroupMemberCount+1, self.nPrevMemberCount do
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
	if self.wndRaidCustomizeCategories:IsChecked() then
		tCategoriesToUse = ktRoleCategoriesToUse
	end

	if self.nNumReadyCheckResponses >= 0 then
		self.nNumReadyCheckResponses = 0 -- Will get added up in UpdateSpecificMember
	end

	local nInvalidOrDeadMembers = 0
	local unitTarget = self.unitTarget
	local bFrameLocked = self.wndRaidLockFrameBtn:IsChecked()

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
		
		wndRaidCategoryBtn:Show(not self.wndRaidLockFrameBtn:IsChecked())
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
		local tRaidMember = self:FactoryMemberWindow(wndRaidCategoryItems, nCodeIdx)
		self:UpdateSpecificMember(tRaidMember, nCodeIdx, tMemberData, nGroupMemberCount, bFrameLocked)
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

	local unitTarget = GameLib.GetTargetUnit()
	for idx, tRaidMember in pairs(self.arMemberIndexToWindow) do
		local wndMemberBtn = tRaidMember.wndRaidMemberBtn
	
		local tMemberData = GroupLib.GetGroupMember(idx)
	
		-- HP and Shields
		local unitCurr = GroupLib.GetUnitForGroupMember(idx)
		if unitCurr then
			local bTargetThisMember = unitTarget and unitTarget == unitCurr
			wndMemberBtn:SetCheck(bTargetThisMember)
			tRaidMember.wndRaidTearOffBtn:Show(bTargetThisMember and not bFrameLocked and not self.tTearOffMemberIDs[nCodeIdx])
			self:DoHPAndShieldResizing(tRaidMember, unitCurr)
	
			-- Mana Bar
			local bShowManaBar = self.wndRaidCustomizeManaBar:IsChecked()
			if bShowManaBar and tMemberData.nManaMax and tMemberData.nManaMax > 0 then
				local wndManaBar = self:LoadByName("RaidMemberManaBar", wndMemberBtn, "RaidMemberManaBar")
				wndManaBar:SetMax(tMemberData.nManaMax)
				wndManaBar:SetProgress(tMemberData.nMana)
				wndManaBar:Show(tMemberData.bIsOnline and not bDead and not bOutOfRange and unitCurr:GetHealth() > 0 and unitCurr:GetMaxHealth() > 0)
			end
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

function RaidFrameBase:UpdateOffsets()
	self.nRaidMemberWidth = (self.wndMain:GetWidth() - 22) / self.nNumColumns
	
	-- Calculate this outside the loop, as its the same for entry (TODO REFACTOR)
	self.nLeftOffsetStartValue = 0
	if self.wndRaidCustomizeClassIcons:IsChecked() then
		self.nLeftOffsetStartValue = self.nLeftOffsetStartValue + 16 --wndRaidMember:FindChild("RaidMemberClassIcon"):GetWidth()
	end

	if self.nNumReadyCheckResponses >= 0 then
		self.nLeftOffsetStartValue = self.nLeftOffsetStartValue + 16 --wndRaidMember:FindChild("RaidMemberReadyIcon"):GetWidth()
	end
end

function RaidFrameBase:ResizeAllFrames()
	self:UpdateOffsets()

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
	local nLeftOffset = self.nLeftOffsetStartValue
	if tRaidMember.wndRaidMemberIsLeader:IsShown() then
		nLeftOffset = nLeftOffset + tRaidMember.wndRaidMemberIsLeader:GetWidth()
	end
	if tRaidMember.wndRaidMemberRoleIcon:IsShown() then
		nLeftOffset = nLeftOffset + tRaidMember.wndRaidMemberRoleIcon:GetWidth()
	end
	if tRaidMember.wndRaidMemberMarkIcon:IsShown() then
		nLeftOffset = nLeftOffset + tRaidMember.wndRaidMemberMarkIcon:GetWidth()
	end
	if tRaidMember.wndRaidTearOffBtn:IsShown() then
		nLeftOffset = nLeftOffset + tRaidMember.wndRaidTearOffBtn:GetWidth()
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

function RaidFrameBase:UpdateSpecificMember(tRaidMember, nCodeIdx, tMemberData, nGroupMemberCount, bFrameLocked)
	local wndRaidMember = tRaidMember.wnd
	if not wndRaidMember or not wndRaidMember:IsValid() then
		return
	end

	local wndMemberBtn = tRaidMember.wndRaidMemberBtn
	local unitTarget = self.unitTarget

	tRaidMember.wndHealthBar:Show(false)
	tRaidMember.wndMaxAbsorbBar:Show(false)
	tRaidMember.wndMaxShieldBar:Show(false)
	tRaidMember.wndCurrShieldBar:Show(false)
	tRaidMember.wndRaidMemberMouseHack:SetData(tMemberData.nMemberIdx)

	tRaidMember.wndRaidTearOffBtn:SetData(nCodeIdx)

	local bOutOfRange = tMemberData.nHealthMax == 0
	local bDead = tMemberData.nHealth == 0 and tMemberData.nHealthMax ~= 0
	if not tMemberData.bIsOnline then
		wndMemberBtn:Enable(false)
		wndMemberBtn:ChangeArt("CRB_Raid:btnRaid_ThinHoloRedBtn")
		tRaidMember.wndRaidMemberStatusIcon:SetSprite("CRB_Raid:sprRaid_Icon_Disconnect")
		tRaidMember.wndRaidMemberName:SetText(String_GetWeaselString(Apollo.GetString("Group_OfflineMember"), tMemberData.strCharacterName))
	elseif bDead then
		wndMemberBtn:Enable(true)
		wndMemberBtn:ChangeArt("CRB_Raid:btnRaid_ThinHoloRedBtn")
		tRaidMember.wndRaidMemberStatusIcon:SetSprite("")
		tRaidMember.wndRaidMemberName:SetText(String_GetWeaselString(Apollo.GetString("Group_DeadMember"), tMemberData.strCharacterName))
	elseif bOutOfRange then
		wndMemberBtn:Enable(false)
		wndMemberBtn:ChangeArt("CRB_Raid:btnRaid_ThinHoloBlueBtn")
		tRaidMember.wndRaidMemberStatusIcon:SetSprite("CRB_Raid:sprRaid_Icon_OutOfRange")
		tRaidMember.wndRaidMemberName:SetText(String_GetWeaselString(Apollo.GetString("Group_OutOfRange"), tMemberData.strCharacterName))
	else
		wndMemberBtn:Enable(true)
		wndMemberBtn:ChangeArt("CRB_Raid:btnRaid_ThinHoloBlueBtn")
		tRaidMember.wndRaidMemberStatusIcon:SetSprite("")
		tRaidMember.wndRaidMemberName:SetText(tMemberData.strCharacterName)
	end

	tRaidMember.wndRaidMemberName:Show(self.wndRaidCustomizeShowNames:IsChecked())

	local bShowClassIcon = self.wndRaidCustomizeClassIcons:IsChecked()
	local wndClassIcon = tRaidMember.wndRaidMemberClassIcon
	if bShowClassIcon then
		wndClassIcon:SetSprite(ktIdToClassSprite[tMemberData.eClassId])
		wndClassIcon:SetTooltip(Apollo.GetString(ktIdToClassTooltip[tMemberData.eClassId]))
	end
	wndClassIcon:Show(bShowClassIcon)

	local nLeaderIdx = 0
	local bShowLeaderIcon = self.wndRaidCustomizeLeaderIcons:IsChecked()
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

	local nRoleIdx = -1
	local bShowRoleIcon = self.wndRaidCustomizeRoleIcons:IsChecked()
	local wndRoleIcon = tRaidMember.wndRaidMemberRoleIcon

	if bShowRoleIcon then
		if tMemberData.bDPS then
			nRoleIdx = MatchingGame.Roles.DPS
		elseif tMemberData.bHealer then
			nRoleIdx = MatchingGame.Roles.Healer
		elseif tMemberData.bTank then
			nRoleIdx = MatchingGame.Roles.Tank
		end
		local tPixieInfo = wndRoleIcon:GetPixieInfo(1)
		if tPixieInfo then
			tPixieInfo.strSprite = ktIdToRoleSprite[nRoleIdx]
			wndRoleIcon:UpdatePixie(1, tPixieInfo)
		end
		--wndRoleIcon:SetSprite(ktIdToRoleSprite[nRoleIdx])
		wndRoleIcon:SetTooltip(Apollo.GetString(ktIdToRoleTooltip[nRoleIdx]))
	end
	wndRoleIcon:Show(bShowRoleIcon and nRoleIdx ~= -1)

	local nMarkIdx = 0
	local bShowMarkIcon = self.wndRaidCustomizeMarkIcons:IsChecked()
	local wndMarkIcon = tRaidMember.wndRaidMemberMarkIcon
	if bShowMarkIcon then
		nMarkIdx = tMemberData.nMarkerId or 0
		wndMarkIcon:SetSprite(kstrRaidMarkerToSprite[nMarkIdx])
	end
	wndMarkIcon:Show(bShowMarkIcon and nMarkIdx ~= 0)

	-- Ready Check
	if self.nNumReadyCheckResponses >= 0 then
		local wndReadyCheckIcon = tRaidMember.wndRaidMemberReadyIcon
		if tMemberData.bHasSetReady and tMemberData.bReady then
			self.nNumReadyCheckResponses = self.nNumReadyCheckResponses + 1
			wndReadyCheckIcon:SetText(Apollo.GetString("RaidFrame_Ready"))
			wndReadyCheckIcon:SetSprite("CRB_Raid:sprRaid_Icon_ReadyCheckDull")
		elseif tMemberData.bHasSetReady and not tMemberData.bReady then
			self.nNumReadyCheckResponses = self.nNumReadyCheckResponses + 1
			wndReadyCheckIcon:SetText("")
			wndReadyCheckIcon:SetSprite("CRB_Raid:sprRaid_Icon_NotReadyDull")
		else
			wndReadyCheckIcon:SetText("")
			wndReadyCheckIcon:SetSprite("")
		end
		wndReadyCheckIcon:Show(true)
		--wndRaidMember:BringChildToTop(wndReadyCheckIcon)

		if self.nNumReadyCheckResponses == nGroupMemberCount then
			self:OnReadyCheckTimeout()
		end
	end

	-- HP and Shields
	local unitCurr = GroupLib.GetUnitForGroupMember(nCodeIdx)
	if unitCurr then
		local bTargetThisMember = unitTarget and unitTarget == unitCurr
		wndMemberBtn:SetCheck(bTargetThisMember)
		tRaidMember.wndRaidTearOffBtn:Show(bTargetThisMember and not bFrameLocked and not self.tTearOffMemberIDs[nCodeIdx])
		self:DoHPAndShieldResizing(tRaidMember, unitCurr)

		-- Mana Bar
		local bShowManaBar = self.wndRaidCustomizeManaBar:IsChecked()
		if bShowManaBar and tMemberData.nManaMax and tMemberData.nManaMax > 0 then
			local wndManaBar = self:LoadByName("RaidMemberManaBar", wndMemberBtn, "RaidMemberManaBar")
			wndManaBar:SetMax(tMemberData.nManaMax)
			wndManaBar:SetProgress(tMemberData.nMana)
			wndManaBar:Show(tMemberData.bIsOnline and not bDead and not bOutOfRange and unitCurr:GetHealth() > 0 and unitCurr:GetMaxHealth() > 0)
		end
	end
	
	self:ResizeMemberFrame(wndRaidMember)
end

function RaidFrameBase:OnTargetUnitChanged(unitOwner)
	local unitOldTarget = self.unitTarget
	self.unitTarget = unitOwner

	if not GroupLib.InRaid() then return end
	
	local nGroupMemberCount = GroupLib.GetMemberCount()
	for nMemberIdx=0,nGroupMemberCount do
		if unitOldTarget ~= nil and unitOldTarget == GroupLib.GetUnitForGroupMember(nMemberIdx) then
			local tRaidMember = self.arMemberIndexToWindow[nMemberIdx]
			local tMemberData = GroupLib.GetGroupMember(nMemberIdx)
			self:UpdateSpecificMember(tRaidMember, nMemberIdx, tMemberData, nGroupMemberCount)
			
			if self.unitTarget == nil then break end
		end
		if self.unitTarget ~= nil and self.unitTarget == GroupLib.GetUnitForGroupMember(nMemberIdx) then
			local tRaidMember = self.arMemberIndexToWindow[nMemberIdx]
			local tMemberData = GroupLib.GetGroupMember(nMemberIdx)
			self:UpdateSpecificMember(tRaidMember, nMemberIdx, tMemberData, nGroupMemberCount)
			
			if unitOldTarget == nil then break end
		end
	end
	
end

-----------------------------------------------------------------------------------------------
-- UI
-----------------------------------------------------------------------------------------------

function RaidFrameBase:OnRaidCategoryBtnToggle(wndHandler, wndControl) -- RaidCategoryBtn
	local tCategory = wndHandler:GetParent():GetData()
	tCategory.wndRaidCategoryItems:Show(not tCategory.wndRaidCategoryItems:IsShown())
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyResize)
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
end

function RaidFrameBase:OnRaidTearOffBtn(wndHandler, wndControl) -- RaidTearOffBtn
	Event_FireGenericEvent("GenericEvent_Raid_ToggleRaidTearOff", wndHandler:GetData())
	self.tTearOffMemberIDs[wndHandler:GetData()] = true
end

function RaidFrameBase:OnRaidUnTearOff(wndArg) -- GenericEvent_Raid_ToggleRaidUnTear
	self.tTearOffMemberIDs[wndArg] = nil
end

function RaidFrameBase:OnLeaveBtn(wndHandler, wndControl)
	self:OnUncheckLeaderOptions()
	self:OnUncheckMasterLoot()
	GroupLib.LeaveGroup()
end

function RaidFrameBase:OnRaidLeaveShowPrompt(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:FindChild("RaidConfigureBtn") then
		self.wndMain:FindChild("RaidConfigureBtn"):SetCheck(false)
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
	if not self.bReadyCheckActive then
		local strMessage = self.wndMain:FindChild("RaidOptions:SelfConfigReadyCheckLabel:ReadyCheckMessageBG:ReadyCheckMessageEditBox"):GetText()
		if string.len(strMessage) <= 0 then
			strMessage = Apollo.GetString("RaidFrame_AreYouReady")
		end

		GroupLib.ReadyCheck(strMessage) -- Sanitized in code
		self.wndMain:FindChild("RaidConfigureBtn"):SetCheck(false)
		wndHandler:SetFocus() -- To remove out of edit box
		self.bReadyCheckActive = true
	end
end

function RaidFrameBase:OnGroup_ReadyCheck(nMemberIdx, strMessage)
	local tMember = GroupLib.GetGroupMember(nMemberIdx)
	local strName = Apollo.GetString("RaidFrame_TheRaid")
	if tMember then
		strName = tMember.strCharacterName
	end

	if self.wndReadyCheckPopup and self.wndReadyCheckPopup:IsValid() then
		self.wndReadyCheckPopup:Destroy()
	end

	self.wndReadyCheckPopup = Apollo.LoadForm(self.xmlDoc, "RaidReadyCheck", nil, self)
	self.wndReadyCheckPopup:SetData(wndReadyCheckPopup)
	self.wndReadyCheckPopup:FindChild("ReadyCheckNoBtn"):SetData(wndReadyCheckPopup)
	self.wndReadyCheckPopup:FindChild("ReadyCheckYesBtn"):SetData(wndReadyCheckPopup)
	self.wndReadyCheckPopup:FindChild("ReadyCheckCloseBtn"):SetData(wndReadyCheckPopup)
	self.wndReadyCheckPopup:FindChild("ReadyCheckMessage"):SetText(String_GetWeaselString(Apollo.GetString("RaidFrame_ReadyCheckStarted"), strName) .. "\n" .. strMessage)

	self.nNumReadyCheckResponses = 0

	self.strReadyCheckInitiator = strName
	self.strReadyCheckMessage = strMessage
	self.fReadyCheckStartTime = os.clock()
	self.bReadyCheckActive = true

	Apollo.CreateTimer("ReadyCheckTimeout", knReadyCheckTimeout, false)
end

function RaidFrameBase:OnReadyCheckResponse(wndHandler, wndControl)
	if wndHandler == wndControl then
		GroupLib.SetReady(wndHandler:GetName() == "ReadyCheckYesBtn") -- TODO Quick Hack
	end

	if self.wndReadyCheckPopup and self.wndReadyCheckPopup:IsValid() then
		self.wndReadyCheckPopup:Destroy()
	end
end

function RaidFrameBase:OnReadyCheckTimeout()
	self.nNumReadyCheckResponses = -1

	if self.wndReadyCheckPopup and self.wndReadyCheckPopup:IsValid() then
		self.wndReadyCheckPopup:Destroy()
	end

	local strMembersNotReady = ""
	for key, wndCategory in pairs(self.wndRaidCategoryContainer:GetChildren()) do
		for key2, wndMember in pairs(wndCategory:FindChild("RaidCategoryItems"):GetChildren()) do
			if wndMember:FindChild("RaidMemberReadyIcon") and wndMember:FindChild("RaidMemberReadyIcon"):IsValid() then
				if wndMember:FindChild("RaidMemberReadyIcon"):GetText() ~= Apollo.GetString("RaidFrame_Ready") then
					if strMembersNotReady == "" then
						strMembersNotReady = wndMember:FindChild("RaidMemberName"):GetText()
					else
						strMembersNotReady = String_GetWeaselString(Apollo.GetString("RaidFrame_NotReadyList"), strMembersNotReady, wndMember:FindChild("RaidMemberName"):GetText())
					end
				end
				--wndMember:FindChild("RaidMemberReadyIcon"):Destroy()
				wndMember:FindChild("RaidMemberReadyIcon"):Show(false)
			elseif strMembersNotReady == "" then
				strMembersNotReady = wndMember:FindChild("RaidMemberName"):GetText()
			else
				strMembersNotReady = String_GetWeaselString(Apollo.GetString("RaidFrame_NotReadyList"), strMembersNotReady, wndMember:FindChild("RaidMemberName"):GetText())
			end
		end
	end

	self:OnRaidFrameBaseTimer()

	if strMembersNotReady == "" then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Party, Apollo.GetString("RaidFrame_ReadyCheckSuccess"), "")
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Party, String_GetWeaselString(Apollo.GetString("RaidFrame_ReadyCheckFail"), strMembersNotReady), "")
	end

	self.bReadyCheckActive = false
end

-----------------------------------------------------------------------------------------------
-- Self Config and Customization
-----------------------------------------------------------------------------------------------

function RaidFrameBase:OnConfigSetAsDPSToggle(wndHandler, wndControl)
	GroupLib.SetRoleDPS(wndHandler:GetData(), wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameBase:OnConfigSetAsTankToggle(wndHandler, wndControl)
	GroupLib.SetRoleTank(wndHandler:GetData(), wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameBase:OnConfigSetAsHealerToggle(wndHandler, wndControl)
	GroupLib.SetRoleHealer(wndHandler:GetData(), wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameBase:OnRaidMemberBtnClick(wndHandler, wndControl) -- RaidMemberMouseHack
	-- GOTCHA: Use MouseUp instead of ButtonCheck to avoid weird edgecase bugs
	if wndHandler ~= wndControl or not wndHandler or not wndHandler:GetData() then
		return
	end

	local unit = GroupLib.GetUnitForGroupMember(wndHandler:GetData())
	if unit then
		GameLib.SetTargetUnit(unit)
		self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyResize)
	end
end

function RaidFrameBase:OnRaidLockFrameBtnToggle(wndHandler, wndControl) -- RaidLockFrameBtn
	self.wndMain:SetStyle("Sizable", not wndHandler:IsChecked())
	self.wndMain:SetStyle("Moveable", not wndHandler:IsChecked())
	if wndHandler:IsChecked() then
		self.wndMain:SetSprite("sprRaid_BaseNoArrow")
	else
		self.wndMain:SetSprite("sprRaid_Base")
	end
end

function RaidFrameBase:OnRaidCustomizeNumColAdd(wndHandler, wndControl) -- RaidCustomizeNumColAdd, and once from bSwapToTwoColsOnce
	self.nNumColumns = self.nNumColumns + 1
	if self.nNumColumns >= 5 then
		self.nNumColumns = 5
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeNumColSub:Enable(true)
	self.wndRaidCustomizeNumColValue:SetText(self.nNumColumns)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyResize)
end

function RaidFrameBase:OnRaidCustomizeNumColSub(wndHandler, wndControl) -- RaidCustomizeNumColSub
	self.nNumColumns = self.nNumColumns - 1
	if self.nNumColumns <= 1 then
		self.nNumColumns = 1
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeNumColAdd:Enable(true)
	self.wndRaidCustomizeNumColValue:SetText(self.nNumColumns)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyResize)
end

function RaidFrameBase:OnRaidCustomizeRowSizeAdd(wndHandler, wndControl) -- RaidCustomizeRowSizeAdd
	self.nRowSize = self.nRowSize + 1
	if self.nRowSize >= 5 then
		self.nRowSize = 5
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeRowSizeSub:Enable(true)
	self.wndRaidCustomizeRowSizeValue:SetText(self.nRowSize)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyResize)
end

function RaidFrameBase:OnRaidCustomizeRowSizeSub(wndHandler, wndControl) -- RaidCustomizeRowSizeSub
	self.nRowSize = self.nRowSize - 1
	if self.nRowSize <= 1 then
		self.nRowSize = 1
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeRowSizeAdd:Enable(true)
	self.wndRaidCustomizeRowSizeValue:SetText(self.nRowSize)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyResize)
end

function RaidFrameBase:DestroyAndRedrawAllFromUI(wndHandler, wndControl) -- RaidCustomizeRoleIcons
	self:OnDestroyAndRedrawAll()
end

function RaidFrameBase:OnDestroyAndRedrawAll() -- DestroyAndRedrawAllFromUI
	if self.wndMain and self.wndMain:IsValid() then
		self.wndRaidCategoryContainer:DestroyChildren()
		self:OnRaidFrameBaseTimer()
		self:OnRaidFrameBaseTimer() -- TODO HACK to immediate redraw
	end
end

function RaidFrameBase:DestroyMemberWindows(nMemberIdx)
	local tCategoriesToUse = {Apollo.GetString("RaidFrame_Members")}
	if self.wndRaidCustomizeCategories:IsChecked() then
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

function RaidFrameBase:OnRaidWindowSizeChanged(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyResize)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function RaidFrameBase:OnEnteredCombat(unit, bInCombat)
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsVisible() and unit == GameLib.GetPlayerUnit() and self.wndMain:FindChild("RaidCustomizeLockInCombat"):IsChecked() then
		self.wndRaidLockFrameBtn:SetCheck(bInCombat)
		self:OnRaidLockFrameBtnToggle(self.wndRaidLockFrameBtn, self.wndRaidLockFrameBtn)
	end
end

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
	if not unitPlayer then
		return
	end

	local wndMemberBtn = tRaidMember.wndRaidMemberBtn
	
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

	local wndHealthBarGlow = tRaidMember.wndHealthBarEdgeGlow
	wndHealthBarGlow:Show(nShieldMax <= 0)

	-- Health Bar Color
	if (nHealthCurr / nHealthMax) < self.nHealthWarn then
		wndHealthBar:SetSprite("sprRaid_HealthProgBar_Red")
		wndHealthBarGlow:SetSprite("sprRaid_HealthEdgeGlow_Red")
	elseif (nHealthCurr / nHealthMax) < self.nHealthWarn2 then
		wndHealthBar:SetSprite("sprRaid_HealthProgBar_Orange")
		wndHealthBarGlow:SetSprite("sprRaid_HealthEdgeGlow_Orange")
	else
		wndHealthBar:SetSprite("sprRaid_HealthProgBar_Green")
		wndHealthBarGlow:SetSprite("sprRaid_HealthEdgeGlow_Green")
	end

	-- Scaling
	local nArtOffset = 2
	local nWidth = wndMemberBtn:GetWidth() - 4
	local nPointHealthRight = nWidth * (nHealthCurr / nTotalMax)
	local nPointShieldRight = nWidth * ((nHealthCurr + nShieldMax) / nTotalMax)
	local nPointAbsorbRight = nWidth * ((nHealthCurr + nShieldMax + nAbsorbMax) / nTotalMax)

	local nLeft, nTop, nRight, nBottom = wndHealthBar:GetAnchorOffsets()
	if not self.wndRaidCustomizeFixedShields:IsChecked() then
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
			wndHealthBarEdgeGlow = wndNew:FindChild("RaidMemberBtn:HealthBar:HealthBarEdgeGlow"),
			wndMaxAbsorbBar = wndNew:FindChild("RaidMemberBtn:MaxAbsorbBar"),
			wndCurrAbsorbBar = wndNew:FindChild("RaidMemberBtn:MaxAbsorbBar:CurrAbsorbBar"),
			wndMaxShieldBar = wndNew:FindChild("RaidMemberBtn:MaxShieldBar"),
			wndCurrShieldBar = wndNew:FindChild("RaidMemberBtn:MaxShieldBar:CurrShieldBar"),
			wndRaidMemberBtn = wndNew:FindChild("RaidMemberBtn"),
			wndRaidMemberMouseHack = wndNew:FindChild("RaidMemberBtn:RaidMemberMouseHack"),
			wndRaidMemberStatusIcon = wndNew:FindChild("RaidMemberBtn:RaidMemberStatusIcon"),
			wndRaidTearOffBtn = wndNew:FindChild("RaidTearOffBtn"),
			wndRaidMemberName = wndNew:FindChild("RaidMemberName"),
			wndRaidMemberClassIcon = wndNew:FindChild("RaidMemberClassIcon"),
			wndRaidMemberIsLeader = wndNew:FindChild("RaidMemberIsLeader"),
			wndRaidMemberRoleIcon = wndNew:FindChild("RaidMemberRoleIcon"),
			wndRaidMemberReadyIcon = wndNew:FindChild("RaidMemberReadyIcon"),
			wndRaidMemberMarkIcon = wndNew:FindChild("RaidMemberMarkIcon"),
		}
		wndNew:SetData(tbl)
		self.cache[strKey] = tbl
		
		for strCacheKey, wndCached in pairs(self.cache) do
			if not self.cache[strCacheKey].wnd:IsValid() then
				self.cache[strCacheKey] = nil
			end
		end
		
		self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyResize)
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
		
		self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyResize)
	end
	
	return tbl
end

function RaidFrameBase:LoadByName(strFormName, wndParent, strKey)
	local wnd = self.arWindowMap[strKey]
	if wnd == nil or not wnd:IsValid() then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetName(strKey)
		self.arWindowMap[strKey] = wnd
		
		for strKey, wndCached in pairs(self.arWindowMap) do
			if not self.arWindowMap[strKey]:IsValid() then
				self.arWindowMap[strKey] = nil
			end
		end
	end
	
	return wnd
end

---------------------------------------------------------------------------------------------------
-- RaidFrameBaseForm Functions
---------------------------------------------------------------------------------------------------

function RaidFrameBase:OnRaidCustomizeCategoryCheck(wndHandler, wndControl, eMouseButton)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyGeneral, knDirtyResize)
end

function RaidFrameBase:OnRaidCustomizeShowNamesCheck(wndHandler, wndControl, eMouseButton)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers)
end

function RaidFrameBase:OnRaidCustomizeDirtyMembers(wndHandler, wndControl, eMouseButton)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers)
end

function RaidFrameBase:OnRaidCustomizeClassIconsCheck(wndHandler, wndControl, eMouseButton)
	self.nDirtyFlag = bit32.bor(self.nDirtyFlag, knDirtyMembers, knDirtyResize)
end

local RaidFrameBaseInst = RaidFrameBase:new()
RaidFrameBaseInst:Init()






