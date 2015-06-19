-------------------------------------------------------------------------------------------
-- Client Lua Script for RaidFrameBase
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

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
	[1] = 21,
	[2] = 23,
	[3] = 25,
	[4] = 27,
	[5] = 30,
	[6] = 33,
	[7] = 36,
	[8] = 39,
	[9] = 42,
}

local knNumColumnsMax = 5
local knReadyCheckTimeout = 16 -- in seconds
local ktGeneralCategories = {Apollo.GetString("RaidFrame_Members")}
local ktRoleCategoriesToUse = {Apollo.GetString("RaidFrame_Tanks"), Apollo.GetString("RaidFrame_Healers"), Apollo.GetString("RaidFrame_DPS")}

local knMinWidth = 175
local knMaxWidth = 1000
local knHealthCritical = 0.3
local knHealthWarn = 0.5

local knSaveVersion = 10

function RaidFrameBase:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.tMemberWindowsByMemberIdx = {}
	o.tMemberWindowsByCharacterName = {}
	
	o.tSettings =
	{
		bShowLeaderIcons		= true,
		bShowClassIcons			= false,
		bShowMarkIcons			= false,
		bShowManaBar			= false,
		bShowFixedShields		= false,
		bShowCategories			= true,
		bShowNames				= true,
		bLockInCombat			= true,
		bInstantHealthUpdate	= false,
		nRowSize				= 1,
		nNumColumns				= 1,
		bIsLocked				= false,
	}

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

	return
	{
		nSaveVersion 			= knSaveVersion,
		bShowLeaderIcons		= self.tSettings.bShowLeaderIcons,
		bShowClassIcons			= self.tSettings.bShowClassIcons,
		bShowMarkIcons			= self.tSettings.bShowMarkIcons,
		bShowManaBar			= self.tSettings.bShowManaBar,
		bShowFixedShields		= self.tSettings.bShowFixedShields,
		bShowCategories			= self.tSettings.bShowCategories,
		bShowNames				= self.tSettings.bShowNames,
		bLockInCombat			= self.tSettings.bLockInCombat,
		bInstantHealthUpdate	= self.tSettings.bInstantHealthUpdate,
		nRowSize				= self.tSettings.nRowSize,
		nNumColumns				= self.tSettings.nNumColumns,
		bIsLocked				= self.tSettings.bIsLocked,
	}
end

function RaidFrameBase:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	if tSavedData.bShowLeaderIcons ~= nil then
		self.tSettings.bShowLeaderIcons = tSavedData.bShowLeaderIcons
	end
	if tSavedData.bShowClassIcons ~= nil then
		self.tSettings.bShowClassIcons = tSavedData.bShowClassIcons
	end
	if tSavedData.bShowMarkIcons ~= nil then
		self.tSettings.bShowMarkIcons = tSavedData.bShowMarkIcons
	end
	if tSavedData.bShowManaBar ~= nil then
		self.tSettings.bShowManaBar = tSavedData.bShowManaBar
	end
	if tSavedData.bShowFixedShields ~= nil then
		self.tSettings.bShowFixedShields = tSavedData.bShowFixedShields
	end
	if tSavedData.bShowCategories ~= nil then
		self.tSettings.bShowCategories = tSavedData.bShowCategories
	end
	if tSavedData.bShowNames ~= nil then
		self.tSettings.bShowNames = tSavedData.bShowNames
	end
	if tSavedData.bLockInCombat ~= nil then
		self.tSettings.bLockInCombat = tSavedData.bLockInCombat
	end
	if tSavedData.bInstantHealthUpdate ~= nil then
		self.tSettings.bInstantHealthUpdate = tSavedData.bInstantHealthUpdate
	end
	if tSavedData.nRowSize ~= nil then
		self.tSettings.nRowSize = tSavedData.nRowSize
	end
	if tSavedData.nNumColumns  ~= nil then
		self.tSettings.nNumColumns = tSavedData.nNumColumns
	end
	if tSavedData.bIsLocked ~= nil then
		self.tSettings.bIsLocked = tSavedData.bIsLocked
	end
	
	if self.wndMain ~= nil and self.wndMain:IsValid() then
		self:HelperUpdateSettings()
	end
end

function RaidFrameBase:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("CharacterCreated",							"OnCharacterCreated", self)
	Apollo.RegisterEventHandler("GenericEvent_Raid_UncheckMasterLoot",		"OnUncheckMasterLoot", self)
	Apollo.RegisterEventHandler("GenericEvent_Raid_UncheckLeaderOptions",	"OnUncheckLeaderOptions", self)
	Apollo.RegisterEventHandler("WindowManagementReady",					"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("VarChange_FrameCount",						"OnFrame", self)
	
	Apollo.RegisterEventHandler("UnitCreated",								"OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed",							"OnUnitDestroyed", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat",						"OnEnteredCombat", self)
	Apollo.RegisterEventHandler("Group_Join",								"OnGroup_Join", self)
	Apollo.RegisterEventHandler("Group_Left",								"OnGroup_Left", self)
	Apollo.RegisterEventHandler("Group_Add",								"OnGroup_Add", self)
	Apollo.RegisterEventHandler("Group_Remove",								"OnGroup_Remove", self) -- Kicked, or someone else leaves (yourself leaving is Group_Leave)
	Apollo.RegisterEventHandler("Group_MemberFlagsChanged",					"OnGroup_MemberFlagsChanged", self)
	Apollo.RegisterEventHandler("Group_FlagsChanged",						"OnGroup_FlagsChanged", self)
	Apollo.RegisterEventHandler("Group_SetMark",							"OnGroup_SetMark", self)
	Apollo.RegisterEventHandler("Group_LootRulesChanged",					"OnGroup_LootRulesChanged", self)
	Apollo.RegisterEventHandler("MasterLootUpdate",							"OnMasterLootUpdate", self)

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
	
	local wndRaidOptions = self.wndMain:FindChild("RaidOptions:SelfConfigRaidCustomizeOptions")
	wndRaidOptions:FindChild("RaidCustomizeLeaderIcons"):SetData("bShowLeaderIcons")
	wndRaidOptions:FindChild("RaidCustomizeClassIcons"):SetData("bShowClassIcons")
	wndRaidOptions:FindChild("RaidCustomizeMarkIcons"):SetData("bShowMarkIcons")
	wndRaidOptions:FindChild("RaidCustomizeManaBar"):SetData("bShowManaBar")
	wndRaidOptions:FindChild("RaidCustomizeFixedShields"):SetData("bShowFixedShields")
	wndRaidOptions:FindChild("RaidCustomizeCategories"):SetData("bShowCategories")
	wndRaidOptions:FindChild("RaidCustomizeShowNames"):SetData("bShowNames")
	wndRaidOptions:FindChild("RaidCustomizeInstantHealthUpdates"):SetData("bInstantHealthUpdate")
	wndRaidOptions:FindChild("RaidCustomizeLockInCombat"):SetData("bLockInCombat")
	
	self.wndRaidCustomizeNumColAdd = wndRaidOptions:FindChild("RaidCustomizeNumColText:RaidCustomizeNumColAdd")
	self.wndRaidCustomizeNumColSub = wndRaidOptions:FindChild("RaidCustomizeNumColText:RaidCustomizeNumColSub")
	self.wndRaidCustomizeNumColValue = wndRaidOptions:FindChild("RaidCustomizeNumColText:RaidCustomizeNumColValue")
	self.wndRaidCustomizeRowSizeSub = wndRaidOptions:FindChild("RaidCustomizeRowSizeText:RaidCustomizeRowSizeSub")
	self.wndRaidCustomizeRowSizeAdd = wndRaidOptions:FindChild("RaidCustomizeRowSizeText:RaidCustomizeRowSizeAdd")
	self.wndRaidCustomizeRowSizeValue = wndRaidOptions:FindChild("RaidCustomizeRowSizeText:RaidCustomizeRowSizeValue")
	self.wndRaidLockFrameBtn = self.wndMain:FindChild("RaidLockFrameBtn")
	
	local wndMeasure = Apollo.LoadForm(self.xmlDoc, "RaidCategory", nil, self)
	self.knWndCategoryHeight = wndMeasure:GetHeight()
	wndMeasure:Destroy()
	
	self.knBaseMainHeight = self.wndMain:GetHeight() - self.wndRaidCategoryContainer:GetHeight()

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self:OnCharacterCreated()
	end
end

function RaidFrameBase:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndMain, strName = Apollo.GetString("CRB_Raid") })
	
	local wndCategoryContainer = self.wndMain:FindChild("RaidCategoryContainer")
	local nCategoryContainerHeight = wndCategoryContainer:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.knBaseMainHeight + nCategoryContainerHeight)
	
	local nMainHeight = self.wndMain:GetHeight()
	self.wndMain:SetSizingMinimum(knMinWidth, nMainHeight)
	self.wndMain:SetSizingMaximum(knMaxWidth, nMainHeight)
end

function RaidFrameBase:OnCharacterCreated()
	if not GroupLib.InRaid() then
		return
	end
	
	self.wndRaidCategoryContainer:DestroyChildren()
	self.tMemberWindowsByMemberIdx = {}
	self.tMemberWindowsByCharacterName = {}
	
	self:HelperUpdateSettings()
	self:UpdateLootRules()
	self:BuildMembers()
	self:UpdateRaidOptions()
	
	self.wndMain:Show(true)
end

function RaidFrameBase:OnFrame()
	if not GroupLib.InRaid() then
		return
	end

	local bInstantHealth = self.tSettings.bInstantHealthUpdate
	
	local nInvalidOrDeadMembers = 0
	local nMemberCount = GroupLib.GetMemberCount()
	for memberIndex = 1, nMemberCount do
		local tMember = GroupLib.GetGroupMember(memberIndex)
		local tWndMember = self.tMemberWindowsByMemberIdx[tMember.nMemberIdx]
		if tWndMember ~= nil and tWndMember.wndMember ~= nil and tWndMember.wndMember:IsValid() then
			
			local unitMember = GroupLib.GetUnitForGroupMember(tMember.nMemberIdx)
			if unitMember ~= nil then
				local nHealthCurr = unitMember:GetHealth()
				local nHealthMax = unitMember:GetMaxHealth()
				local nShieldCurr = unitMember:GetShieldCapacity()
				local nShieldMax = unitMember:GetShieldCapacityMax()
				local nAbsorbCurr = 0
				local nAbsorbMax = unitMember:GetAbsorptionMax()
				if nAbsorbMax > 0 then
					nAbsorbCurr = unitMember:GetAbsorptionValue() -- Since it doesn't clear when the buff drops off
				end
				local nManaCurr = unitMember:GetMana()
				local nManaMax = unitMember:GetMaxMana() or nManaCurr
				
				if tWndMember.nLastKnownHealth ~= nHealthCurr and (tWndMember.nLastKnownHealth == 0 or nHealthCurr == 0) then
					self:BuildMember(tWndMember.wndParent, tMember)
				else
					self:DrawHealth(tWndMember, nHealthCurr, nHealthMax, nShieldCurr, nShieldMax, nAbsorbCurr, nAbsorbMax, nManaCurr, nManaMax, bInstantHealth)
				end
			else
				if tWndMember.nLastKnownHealth ~= nHealthCurr and (tWndMember.nLastKnownHealth == 0 or nHealthCurr == 0) then
					self:BuildMember(tWndMember.wndParent, tMember)
				else
					self:DrawHealth(tWndMember, tMember.nHealth, tMember.nHealthMax, tMember.nShield, tMember.nShieldMax, tMember.nAbsorption, tMember.nAbsorptionMax, tMember.nMana, tMember.nManaMax, bInstantHealth)
				end
			end
			
			if not tMember.bIsOnline or tMember.nHealthMax == 0 or tMember.nHealth == 0 then
				nInvalidOrDeadMembers = nInvalidOrDeadMembers + 1
			end
		end
	end
	
	self.wndRaidTitle:SetText(String_GetWeaselString(Apollo.GetString("RaidFrame_MemberCount"), nMemberCount - nInvalidOrDeadMembers, nMemberCount))
end

function RaidFrameBase:DrawHealth(tWndMember, nHealthCurr, nHealthMax, nShieldCurr, nShieldMax, nAbsorbCurr, nAbsorbMax, nManaCurr, nManaMax, bInstantProgress)
	local wndMemberBtn = tWndMember.wndMemberBtn
	local wndHealthBar = tWndMember.wndHealthBar
	local wndAbsorbBar = tWndMember.wndAbsorbBar
	local wndShieldBar = tWndMember.wndShieldBar
	local wndManaBar = tWndMember.wndManaBar
	
	if nHealthCurr == 0 then
		nShieldCurr = 0
		nAbsorbCurr = 0
		nManaCurr = 0
	end
	
	tWndMember.nLastKnownHealth = nHealthCurr
	local nHealthDisplayMax = self.tSettings.bShowFixedShields and nHealthMax or (nHealthMax + nShieldMax + nAbsorbMax)
	wndHealthBar:SetMax(nHealthDisplayMax)
	if bInstantProgress then
		wndHealthBar:SetProgress(nHealthCurr)
	else
		wndHealthBar:SetProgress(nHealthCurr, nHealthDisplayMax * 4)
	end
	
	local nShieldAbsorbDisplayMax = self.tSettings.bShowFixedShields and (nShieldMax + nAbsorbMax) or (nHealthMax + nShieldMax + nAbsorbMax)
	
	wndShieldBar:SetMax(nShieldAbsorbDisplayMax)
	local nShieldDisplay = self.tSettings.bShowFixedShields and nShieldCurr or (nHealthCurr+nShieldCurr)
	if bInstantProgress then
		wndShieldBar:SetProgress(nShieldDisplay)
	else
		wndShieldBar:SetProgress(nShieldDisplay, nShieldAbsorbDisplayMax * 4)
	end
	
	wndAbsorbBar:SetMax(nShieldAbsorbDisplayMax)
	local nAbsorbDisplay = self.tSettings.bShowFixedShields and (nShieldCurr+nAbsorbCurr) or (nHealthCurr+nShieldCurr+nAbsorbCurr)
	if bInstantProgress then
		wndAbsorbBar:SetProgress(nAbsorbDisplay)
	else
		wndAbsorbBar:SetProgress(nAbsorbDisplay, nShieldAbsorbDisplayMax * 4)
	end
	
	-- Health Bar Color
	if (nHealthCurr / nHealthMax) < knHealthCritical then
		wndHealthBar:SetFullSprite("sprRaid_HealthProgBar_Red")
	elseif (nHealthCurr / nHealthMax) < knHealthWarn then
		wndHealthBar:SetFullSprite("sprRaid_HealthProgBar_Orange")
	else
		wndHealthBar:SetFullSprite("sprRaid_HealthProgBar_Green")
	end
	
	-- Mana Bar
	local bShowManaBar = self.tSettings.bShowManaBar
	if bShowManaBar then
		wndManaBar:SetMax(nManaMax)
		if bInstantProgress then
			wndManaBar:SetProgress(nManaCurr)
		else
			wndManaBar:SetProgress(nManaCurr, nManaMax * 4)
		end
	end
	
	wndManaBar:Show(bShowManaBar and nManaMax > 0 and nHealthCurr > 0 and nHealthMax > 0)
end

function RaidFrameBase:CategorizeMembers()
	local tCategories = {}

	if self.tSettings.bShowCategories then
		local nMemberCount = GroupLib.GetMemberCount()
		for nMemberIdx = 1, nMemberCount do
			local tMember = GroupLib.GetGroupMember(nMemberIdx)
			if tMember.bTank then
				if tCategories[1] == nil then
					tCategories[1] = {}
				end
				tCategories[1][#tCategories[1] + 1] = tMember
			elseif tMember.bHealer then
				if tCategories[2] == nil then
					tCategories[2] = {}
				end
				tCategories[2][#tCategories[2] + 1] = tMember
			else
				if tCategories[3] == nil then
					tCategories[3] = {}
				end
				tCategories[3][#tCategories[3] + 1] = tMember
			end
		end
	else
		tCategories[1] = {}
		local nMemberCount = GroupLib.GetMemberCount()
		for nMemberIdx = 1, nMemberCount do
			tCategories[1][#tCategories[1] + 1] = GroupLib.GetGroupMember(nMemberIdx)
		end
	end
	
	return tCategories
end

function RaidFrameBase:BuildMembers()
	local nMemberCount = GroupLib.GetMemberCount()
	
	local wndCategoryContainer = self.wndMain:FindChild("RaidCategoryContainer")
	
	local tRoleCategories
	if self.tSettings.bShowCategories then
		tRoleCategories = ktRoleCategoriesToUse
	else
		tRoleCategories = ktGeneralCategories
	end
	
	local tMemberCategories = self:CategorizeMembers()
	for idx, tMemberCategory in pairs(tMemberCategories) do
		local wndRaidCategory = wndCategoryContainer:FindChild(tRoleCategories[idx])
		if wndRaidCategory == nil or not wndRaidCategory:IsValid() then
			wndRaidCategory = Apollo.LoadForm(self.xmlDoc, "RaidCategory", wndCategoryContainer, self)
			wndRaidCategory:SetName(tRoleCategories[idx])
			
			wndRaidCategory:FindChild("RaidCategoryName"):SetText(tRoleCategories[idx])
		end
		
		local wndRaidCategoryItems = wndRaidCategory:FindChild("RaidCategoryItems")
		
		local wndRaidCategoryBtn = wndRaidCategory:FindChild("RaidCategoryBtn")
		wndRaidCategoryBtn:Show(not self.tSettings.bIsLocked)
		
		self:BuildMemeberCategory(wndRaidCategoryItems, tMemberCategory)
		
		local nHeight = 0
		if not wndRaidCategoryBtn:IsChecked() then
			for idx, wndColumn in pairs(wndRaidCategoryItems:GetChildren()) do
				local nColumnHeight = wndColumn:GetHeight()
				if nColumnHeight > nHeight then
					nHeight = nColumnHeight
				end
			end
		end
		local nLeft, nTop, nRight, nBottom = wndRaidCategory:GetAnchorOffsets()
		wndRaidCategory:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.knWndCategoryHeight + nHeight)
	end
	
	for idx, wndCategory in pairs(wndCategoryContainer:GetChildren()) do
		local wndRaidCategoryItems = wndCategory:FindChild("RaidCategoryItems")
		local tColumns = wndRaidCategoryItems:GetChildren()
		if #tColumns > 0 then
			local bHasMembers = false
			for idx, wndColumn in pairs(wndRaidCategoryItems:GetChildren()) do
				local wndMemberContainer = wndColumn:FindChild("MemberContainer")
				bHasMembers = bHasMembers or #wndMemberContainer:GetChildren() > 0
			end
			
			if not bHasMembers then
				wndCategory:Destroy()
			end
		else
			wndCategory:Destroy()
		end
	end
	
	local nCategoryContainerHeight = wndCategoryContainer:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop, function(a, b)
		return a:GetName() < b:GetName()
	end)
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.knBaseMainHeight + nCategoryContainerHeight)
	
	local nMainHeight = self.wndMain:GetHeight()
	self.wndMain:SetSizingMinimum(knMinWidth, nMainHeight)
	self.wndMain:SetSizingMaximum(knMaxWidth, nMainHeight)
end

function RaidFrameBase:BuildMemeberCategory(wndCategoryItems, arMembers)
	local arColumns = {}

	local nAnchorPointPart = 1.0 / self.tSettings.nNumColumns
	local nColumnAnchorPointOffset = 0
	for nColumn = 1, self.tSettings.nNumColumns do
		local strWindowName = "Column" .. nColumn
		local wndColumn = wndCategoryItems:FindChild(strWindowName)
		if wndColumn == nil or not wndColumn:IsValid() then
			wndColumn = Apollo.LoadForm(self.xmlDoc, "RaidCategoryColumn", wndCategoryItems, self)
			wndColumn:SetName(strWindowName)
		end
		arColumns[#arColumns + 1] = wndColumn
		
		local nLeft, nTop, nRight, nBottom = wndColumn:GetAnchorPoints()
		
		nLeft = nColumnAnchorPointOffset
		
		nColumnAnchorPointOffset = nColumnAnchorPointOffset + nAnchorPointPart
		
		nRight = nColumnAnchorPointOffset
		if nColumn == self.tSettings.nNumColumns then
			nRight = 1
		end
		
		wndColumn:SetAnchorPoints(nLeft, nTop, nRight, nBottom)
	end
	
	-- add members
	for idx, tMember in pairs(arMembers) do
		local nColumnIndex = (idx % (#arColumns + 1))
		if nColumnIndex == 0 then
			nColumnIndex = 1
		end
		local wndColumn = arColumns[nColumnIndex]
		local wndMemberContainer = wndColumn:FindChild("MemberContainer")
		
		self:BuildMember(wndMemberContainer, tMember)
	end
	
	for idx, wndColumn in pairs(wndCategoryItems:GetChildren()) do
		local wndMemberContainer = wndColumn:FindChild("MemberContainer")
		local nHeight = wndMemberContainer:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop)
		local nLeft, nTop, nRight, nBottom = wndColumn:GetAnchorOffsets()
		wndColumn:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight)
		
		if #wndMemberContainer:GetChildren() == 0 then
			wndColumn:Destroy()
		end
	end
end

function RaidFrameBase:BuildMember(wndMemberContainer, tMember)
	local strWindowName = "Member" .. tMember.nMemberIdx
	local wndMember = wndMemberContainer:FindChild(strWindowName)
	local tWndMember
	if wndMember ~= nil and wndMember:IsValid() and wndMember:GetData() ~= nil then
		tWndMember = self.tMemberWindowsByMemberIdx[wndMember:GetData()]
	end
	if tWndMember == nil or tWndMember.wndMember == nil or not tWndMember.wndMember:IsValid() then
		local wndMember = Apollo.LoadForm(self.xmlDoc, "RaidMember", wndMemberContainer, self)
		wndMember:SetName(strWindowName)
		wndMember:SetData(tMember.nMemberIdx)
		
		tWndMember =
		{
			nMemberIdx = tMember.nMemberIdx,
			nLastKnownHealth = tMember.nHealth,
			wndMember = wndMember,
			wndMemberBtn = wndMember:FindChild("RaidMemberBtn"),
			wndHealthBar = wndMember:FindChild("RaidMemberBtn:HealthBar"),
			wndAbsorbBar = wndMember:FindChild("RaidMemberBtn:AbsorbBar"),
			wndShieldBar = wndMember:FindChild("RaidMemberBtn:ShieldBar"),
			wndManaBar = wndMember:FindChild("RaidMemberBtn:RaidMemberManaBar"),
			wndParent = wndMemberContainer,
		}
		
		if self.tMemberWindowsByMemberIdx[tMember.nMemberIdx] ~= nil then
			self.tMemberWindowsByMemberIdx[tMember.nMemberIdx].wndMember:Destroy()
		end
		self.tMemberWindowsByMemberIdx[tMember.nMemberIdx] = tWndMember
		self.tMemberWindowsByCharacterName[tMember.strCharacterName] = tWndMember
		
		tWndMember.wndMemberBtn:SetData(tMember.nMemberIdx)
	end

	local wndMember	= tWndMember.wndMember

	local wndRaidMemberIcons = wndMember:FindChild("RaidMemberIcons")
	local wndRaidMemberBtn = wndMember:FindChild("RaidMemberBtn")
	
	local wndLeaderIcon = wndRaidMemberIcons:FindChild("RaidMemberIsLeader")
	if self.tSettings.bShowLeaderIcons then
		local nLeaderIdx = 0
		if tMember.bIsLeader then
			nLeaderIdx = 1
		elseif tMember.bMainTank then
			nLeaderIdx = 2
		elseif tMember.bMainAssist then
			nLeaderIdx = 3
		elseif tMember.bRaidAssistant then
			nLeaderIdx = 4
		end
		wndLeaderIcon:SetSprite(ktIdToLeaderSprite[nLeaderIdx])
		wndLeaderIcon:SetTooltip(Apollo.GetString(ktIdToLeaderTooltip[nLeaderIdx]))
	end
	wndLeaderIcon:Show((tMember.bIsLeader or tMember.bMainTank or tMember.bMainAssist or tMember.bRaidAssistant) and self.tSettings.bShowLeaderIcons)

	local wndClass = wndRaidMemberIcons:FindChild("RaidMemberClassIcon")
	wndClass:SetSprite(ktIdToClassSprite[tMember.eClassId])
	wndClass:Show(self.tSettings.bShowClassIcons)
	
	local wndMark = wndRaidMemberIcons:FindChild("RaidMemberMarkIcon")
	wndMark:SetSprite(kstrRaidMarkerToSprite[tMember.nMarkerId])
	wndMark:Show(self.tSettings.bShowMarkIcons)
	
	local nIconsWidth = wndRaidMemberIcons:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
	local nBarsLeft, nBarsTop, nBarsRight, nBarsBottom = wndRaidMemberBtn:GetAnchorOffsets()	
	wndRaidMemberBtn:SetAnchorOffsets(nIconsWidth, nBarsTop, nBarsRight, nBarsBottom)
	
	if self.tSettings.bShowFixedShields then
		local nLeft, nTop, nRight, nBottom
		
		nLeft, nTop, nRight, nBottom = tWndMember.wndHealthBar:GetAnchorPoints()
		tWndMember.wndHealthBar:SetAnchorPoints(nLeft, nTop, 0.9, nBottom)
		
		nLeft, nTop, nRight, nBottom = tWndMember.wndAbsorbBar:GetAnchorPoints()
		tWndMember.wndAbsorbBar:SetAnchorPoints(0.9, nTop, nRight, nBottom)
		
		nLeft, nTop, nRight, nBottom = tWndMember.wndShieldBar:GetAnchorPoints()
		tWndMember.wndShieldBar:SetAnchorPoints(0.9, nTop, nRight, nBottom)
	else
		local nLeft, nTop, nRight, nBottom
		
		nLeft, nTop, nRight, nBottom = tWndMember.wndHealthBar:GetAnchorPoints()
		tWndMember.wndHealthBar:SetAnchorPoints(nLeft, nTop, 1.0, nBottom)
		
		nLeft, nTop, nRight, nBottom = tWndMember.wndAbsorbBar:GetAnchorPoints()
		tWndMember.wndAbsorbBar:SetAnchorPoints(0.0, nTop, nRight, nBottom)
		
		nLeft, nTop, nRight, nBottom = tWndMember.wndShieldBar:GetAnchorPoints()
		tWndMember.wndShieldBar:SetAnchorPoints(0.0, nTop, nRight, nBottom)
	end
	
	local wndName = wndRaidMemberBtn:FindChild("RaidMemberName")
	wndName:Show(self.tSettings.bShowNames)
	
	local unitMember = GroupLib.GetUnitForGroupMember(tMember.nMemberIdx)
	
	local bOutOfRange = tMember.bOutOfRange or unitMember == nil or not unitMember:IsValid()
	local bDead = tMember.nHealth == 0 and tMember.nHealthMax ~= 0
	if not tMember.bIsOnline then
		wndRaidMemberBtn:SetSprite("CRB_Raid:sprRaid_HealthProgBar_Red")
		wndName:SetText(String_GetWeaselString(Apollo.GetString("Group_OfflineMember"), tMember.strCharacterName))
	elseif bDead then
		wndRaidMemberBtn:SetSprite("CRB_Raid:sprRaid_HealthProgBar_Red")
		wndName:SetText(String_GetWeaselString(Apollo.GetString("Group_DeadMember"), tMember.strCharacterName))
	elseif bOutOfRange and tMember.nMemberIdx ~= 1 then
		wndRaidMemberBtn:SetSprite("")
		wndName:SetText(String_GetWeaselString(Apollo.GetString("Group_OutOfRange"), tMember.strCharacterName))
	else
		wndRaidMemberBtn:SetSprite("")
		wndName:SetText(tMember.strCharacterName)
	end

	local nLeft, nTop, nRight, nBottom = wndMember:GetAnchorOffsets()
	wndMember:SetAnchorOffsets(nLeft, nTop, nRight, nTop + ktRowSizeIndexToPixels[self.tSettings.nRowSize])
	
	self:DrawHealth(tWndMember, tMember.nHealth, tMember.nHealthMax, tMember.nShield, tMember.nShieldMax, tMember.nAbsorption, tMember.nAbsorptionMax, tMember.nMana, tMember.nManaMax, true)
end

function RaidFrameBase:OnRaidMemberBtnClick(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl or wndControl == nil or wndControl:GetData() == nil then
		return
	end
	
	if eMouseButton == GameLib.CodeEnumInputMouse.Left then
		local unitMember = GroupLib.GetUnitForGroupMember(wndControl:GetData())
		if unitMember then
			GameLib.SetTargetUnit(unitMember)
		end
	elseif eMouseButton == GameLib.CodeEnumInputMouse.Right then
		local strMemberName = wndHandler:FindChild("RaidMemberName"):GetText()
		local unitMember = GroupLib.GetUnitForGroupMember(wndControl:GetData())
		if unitMember then
			Event_FireGenericEvent("GenericEvent_NewContextMenuPlayerDetailed", wndHandler, strMemberName, unitMember)
		else
			Event_FireGenericEvent("GenericEvent_NewContextMenuPlayer", wndHandler, strMemberName)
		end
	end
end

function RaidFrameBase:UpdateRaidOptions()
	local tMemberData = GroupLib.GetGroupMember(1)

	local wndRaidOptions = self.wndMain:FindChild("RaidOptions")
	local wndRaidOptionsToggles = self.wndMain:FindChild("RaidOptions:SelfConfigSetAsLabel")

	wndRaidOptionsToggles:FindChild("SelfConfigSetAsDPS"):SetCheck(tMemberData.bDPS)
	wndRaidOptionsToggles:FindChild("SelfConfigSetAsHealer"):SetCheck(tMemberData.bHealer)
	wndRaidOptionsToggles:FindChild("SelfConfigSetAsNormTank"):SetCheck(tMemberData.bTank)

	wndRaidOptionsToggles:Show(not tMemberData.bRoleLocked)
	wndRaidOptions:FindChild("SelfConfigReadyCheckLabel"):Show(tMemberData.bIsLeader or tMemberData.bMainTank or tMemberData.bMainAssist or tMemberData.bRaidAssistant)

	local nLeft, nTop, nRight, nBottom = wndRaidOptions:GetAnchorOffsets()
	wndRaidOptions:SetAnchorOffsets(nLeft, nTop, nRight, nTop + wndRaidOptions:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop))
	
	self.wndRaidLeaderOptionsBtn:Show(tMemberData.bIsLeader or tMemberData.bRaidAssistant)
	self.wndRaidMasterLootIconOnly:Show(not tMemberData.bIsLeader)
	self.wndRaidMasterLootBtn:Show(tMemberData.bIsLeader)
end

function RaidFrameBase:OnEnteredCombat(unitArg, bInCombat)
	if not GroupLib.InRaid() then return end
	
	if self.tSettings.bLockInCombat and unitArg == GameLib.GetPlayerUnit() then
		self.tSettings.bIsLocked = bInCombat -- If bLockInCombat then it has control over bIsLocked
		self:HelperUpdateSettings() -- Will update the frame, movable, sizeable
	end
end

function RaidFrameBase:OnUnitCreated(unitNew)
	if not GroupLib.InRaid() then return end

	if unitNew ~= nil and unitNew:IsValid() and unitNew:IsInYourGroup() then
		local tWndMember = self.tMemberWindowsByCharacterName[unitNew:GetName()]
		if tWndMember ~= nil and tWndMember.wndParent ~= nil and tWndMember.wndParent:IsValid() then
			local tMember = GroupLib.GetGroupMember(tWndMember.nMemberIdx)
			if tMember ~= nil then
				self:BuildMember(tWndMember.wndParent, tMember)
			end
		end
	end
end

function RaidFrameBase:OnUnitDestroyed(unitOld)
	if not GroupLib.InRaid() then return end
	
	if unitOld ~= nil and unitOld:IsInYourGroup() then
		local tWndMember = self.tMemberWindowsByCharacterName[unitOld:GetName()]
		if tWndMember ~= nil and tWndMember.wndParent ~= nil and tWndMember.wndParent:IsValid() then
			local tMember = GroupLib.GetGroupMember(tWndMember.nMemberIdx)
			if tMember ~= nil then
				tMember.bOutOfRange = true
				self:BuildMember(tWndMember.wndParent, tMember)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Group Events
-----------------------------------------------------------------------------------------------

function RaidFrameBase:OnGroup_Join()
	if not GroupLib.InRaid() then return end
	self:OnCharacterCreated()
end

function RaidFrameBase:OnGroup_Add(strName)
	if not GroupLib.InRaid() then return end
	self:BuildMembers()
end

function RaidFrameBase:OnGroup_Remove(strName)
	if not GroupLib.InRaid() then return end
	
	self:OnCharacterCreated()
end

function RaidFrameBase:OnGroup_Left()
	local bInRaid = GroupLib.InRaid()
	
	self:OnCharacterCreated()

	self.wndMain:Show(bInRaid)
end

function RaidFrameBase:OnGroup_MemberFlagsChanged(nMemberIdx, bFromPromotion, tChangedFlags)
	if not GroupLib.InRaid() then return end
	
	if nMemberIdx == 1 then
		self:UpdateRaidOptions()
	end
	
	if tChangedFlags.bTank ~= nil or tChangedFlags.bHealer ~= nil or tChangedFlags.bDPS ~= nil then
		self:BuildMembers()
	else
		local tWndMember = self.tMemberWindowsByMemberIdx[nMemberIdx]
		if tWndMember ~= nil and tWndMember.wndParent ~= nil and tWndMember.wndParent:IsValid() then
			self:BuildMember(tWndMember.wndParent, GroupLib.GetGroupMember(nMemberIdx))
		end
	end
end

function RaidFrameBase:OnGroup_FlagsChanged()
	if not GroupLib.InRaid() then
		self.wndMain:Show(false)
		return
	end
	
	if not self.wndMain:IsShown() then
		self:OnCharacterCreated()
	end
end

function RaidFrameBase:OnGroup_SetMark(idMark, unitMarked)
	if not GroupLib.InRaid() then return end
	
	if unitMarked == nil then
		self:BuildMembers()
	elseif unitMarked:IsInYourGroup() then
		local tWndMember = self.tMemberWindowsByCharacterName[unitMarked:GetName()]
		if tWndMember ~= nil and tWndMember.wndParent ~= nil and tWndMember.wndParent:IsValid() then
			self:BuildMember(tWndMember.wndParent, GroupLib.GetGroupMember(tWndMember.nMemberIdx))
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Settings UI
-----------------------------------------------------------------------------------------------

function RaidFrameBase:OnRaidLockFrameBtnToggle(wndHandler, wndControl) -- RaidLockFrameBtn
	self.tSettings.bIsLocked = wndHandler:IsChecked()
	self:HelperUpdateSettings()
end

function RaidFrameBase:OnRaidCategoryBtnToggle(wndHandler, wndControl) -- RaidCategoryBtn
	self:BuildMembers()
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

function RaidFrameBase:OnRaidWrongInstance()
	GroupLib.GotoGroupInstance()
end

-----------------------------------------------------------------------------------------------
-- Loot
-----------------------------------------------------------------------------------------------

function RaidFrameBase:OnGroupBagBtn()
	Event_FireGenericEvent("GenericEvent_ToggleGroupBag")
end

function RaidFrameBase:OnGroup_LootRulesChanged()
	if not GroupLib.InRaid() then return end
	
	self:UpdateLootRules()
end

function RaidFrameBase:OnMasterLootUpdate()
	if not GroupLib.InRaid() then return end
	
	local tMasterLoot = GameLib.GetMasterLoot()
	local bShowMasterLoot = tMasterLoot and #tMasterLoot > 0
	local nLeft, nTop, nRight, nBottom = self.wndRaidTitle:GetAnchorOffsets()
	self.wndRaidTitle:SetAnchorOffsets(bShowMasterLoot and 40 or 12, nTop, nRight, nBottom)

	self.wndGroupBagBtn:Show(bShowMasterLoot)
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

-----------------------------------------------------------------------------------------------
-- Ready Check
-----------------------------------------------------------------------------------------------
function RaidFrameBase:OnReadyCheckChanged(wndHandler, wndControl, strText)
	self.wndMain:FindChild("RaidOptions:SelfConfigReadyCheckLabel:StartReadyCheckBtn"):Enable(GameLib.IsTextValid(strText, GameLib.CodeEnumUserText.ReadyCheck, GameLib.CodeEnumUserTextFilterClass.Strict))
end

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
	wndRaidOptions:FindChild("RaidCustomizeLeaderIcons"):SetCheck(self.tSettings.bShowLeaderIcons)
	wndRaidOptions:FindChild("RaidCustomizeClassIcons"):SetCheck(self.tSettings.bShowClassIcons)
	wndRaidOptions:FindChild("RaidCustomizeMarkIcons"):SetCheck(self.tSettings.bShowMarkIcons)
	wndRaidOptions:FindChild("RaidCustomizeManaBar"):SetCheck(self.tSettings.bShowManaBar)
	wndRaidOptions:FindChild("RaidCustomizeFixedShields"):SetCheck(self.tSettings.bShowFixedShields)
	wndRaidOptions:FindChild("RaidCustomizeCategories"):SetCheck(self.tSettings.bShowCategories)
	wndRaidOptions:FindChild("RaidCustomizeShowNames"):SetCheck(self.tSettings.bShowNames)
	wndRaidOptions:FindChild("RaidCustomizeLockInCombat"):SetCheck(self.tSettings.bLockInCombat)

	self.wndRaidCustomizeRowSizeSub:Enable(self.tSettings.nRowSize > 1)
	self.wndRaidCustomizeRowSizeAdd:Enable(self.tSettings.nRowSize < #ktRowSizeIndexToPixels)
	self.wndRaidCustomizeRowSizeValue:SetText(self.tSettings.nRowSize)
	
	self.wndRaidCustomizeNumColSub:Enable(self.tSettings.nNumColumns > 1)
	self.wndRaidCustomizeNumColAdd:Enable(self.tSettings.nNumColumns < knNumColumnsMax)
	self.wndRaidCustomizeNumColValue:SetText(self.tSettings.nNumColumns)

	-- Lock
	self.wndRaidLockFrameBtn:SetCheck(self.tSettings.bIsLocked)
	self.wndMain:SetStyle("Sizable", not self.tSettings.bIsLocked)
	self.wndMain:SetStyle("Moveable", not self.tSettings.bIsLocked)
	self.wndMain:SetSprite(self.tSettings.bIsLocked and "sprRaid_BaseNoArrow" or "sprRaid_Base")
	local wndCategoryContainer = self.wndMain:FindChild("RaidCategoryContainer")
	for idx, wndCategory in pairs(wndCategoryContainer:GetChildren()) do
		wndCategory:FindChild("RaidCategoryBtn"):Show(not self.tSettings.bIsLocked)
	end
end

function RaidFrameBase:OnConfigSetAsDPSToggle(wndHandler, wndControl)
	GroupLib.SetRoleDPS(1, wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameBase:OnConfigSetAsTankToggle(wndHandler, wndControl)
	GroupLib.SetRoleTank(1, wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameBase:OnConfigSetAsHealerToggle(wndHandler, wndControl)
	GroupLib.SetRoleHealer(1, wndHandler:IsChecked()) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameBase:OnRaidCustomizeCheck(wndHandler, wndControl, eMouseButton)
	self.tSettings[wndControl:GetData()] = wndControl:IsChecked()
	self:BuildMembers()
end

function RaidFrameBase:OnRaidCustomizeNumColAdd(wndHandler, wndControl)
	self.tSettings.nNumColumns = self.tSettings.nNumColumns + 1
	if self.tSettings.nNumColumns >= knNumColumnsMax then
		self.nNumColumns = knNumColumnsMax
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeNumColSub:Enable(true)
	self.wndRaidCustomizeNumColValue:SetText(self.tSettings.nNumColumns)
	self:BuildMembers()
end

function RaidFrameBase:OnRaidCustomizeNumColSub(wndHandler, wndControl)
	self.tSettings.nNumColumns = self.tSettings.nNumColumns - 1
	if self.tSettings.nNumColumns <= 1 then
		self.tSettings.nNumColumns = 1
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeNumColAdd:Enable(true)
	self.wndRaidCustomizeNumColValue:SetText(self.tSettings.nNumColumns)
	self:BuildMembers()
end

function RaidFrameBase:OnRaidCustomizeRowSizeAdd(wndHandler, wndControl)
	self.tSettings.nRowSize = self.tSettings.nRowSize + 1
	if self.tSettings.nRowSize >= #ktRowSizeIndexToPixels then
		self.tSettings.nRowSize = #ktRowSizeIndexToPixels
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeRowSizeSub:Enable(true)
	self.wndRaidCustomizeRowSizeValue:SetText(self.tSettings.nRowSize)
	self:BuildMembers()
end

function RaidFrameBase:OnRaidCustomizeRowSizeSub(wndHandler, wndControl)
	self.tSettings.nRowSize = self.tSettings.nRowSize - 1
	if self.tSettings.nRowSize <= 1 then
		self.tSettings.nRowSize = 1
		wndHandler:Enable(false)
	end
	self.wndRaidCustomizeRowSizeAdd:Enable(true)
	self.wndRaidCustomizeRowSizeValue:SetText(self.tSettings.nRowSize)
	self:BuildMembers()
end

local RaidFrameBaseInst = RaidFrameBase:new()
RaidFrameBaseInst:Init()
