-----------------------------------------------------------------------------------------------
-- Client Lua Script for PathFrame
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "AbilityBook"
require "GameLib"
require "PlayerPathLib"
require "Tooltip"
require "Unit"
 
-----------------------------------------------------------------------------------------------
-- PathFrame Module Definition
-----------------------------------------------------------------------------------------------
local PathFrame = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local knBottomPadding = 48 -- MUST MATCH XML
local knTopPadding = 48 -- MUST MATCH XML
local knPathLASIndex = 10

local knSaveVersion = 1
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function PathFrame:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    return o
end

function PathFrame:Init()
    Apollo.RegisterAddon(self, nil, nil, {"ActionBarFrame", "Abilities"})
end 

-----------------------------------------------------------------------------------------------
-- PathFrame OnLoad
-----------------------------------------------------------------------------------------------
function PathFrame:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathFrame.xml")
	
	self.nSelectedPathId = nil
	self.bHasPathAbilities = false
end

function PathFrame:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSavedData =
	{
		nSelectedPathId = self.nSelectedPathId,
		nSaveVersion = knSaveVersion,
	}

	return tSavedData
end

function PathFrame:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character or not tSavedData or not tSavedData.nSaveVersion or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end

	if tSavedData.nSelectedPathId then
		self.nSelectedPathId = tSavedData.nSelectedPathId
	end
end

function PathFrame:GetAsyncLoadStatus()
	if not (self.xmlDoc and self.xmlDoc:IsLoaded()) then
		return Apollo.AddonLoadStatus.Loading
	end	

	if not self.unitPlayer then
		self.unitPlayer = GameLib.GetPlayerUnit()
	end
	
	if not self.unitPlayer then
		return Apollo.AddonLoadStatus.Loading 
	end
	
	if not Tooltip and Tooltip.GetSpellTooltipForm then
		return Apollo.AddonLoadStatus.Loading
	end
	
	if self:OnAsyncLoad() then
		return Apollo.AddonLoadStatus.Loaded
	end
	
	return Apollo.AddonLoadStatus.Loading
end

function PathFrame:OnAsyncLoad()
	if not Apollo.GetAddon("ActionBarFrame") or not Apollo.GetAddon("Abilities") then
		return
	end
	
	Apollo.RegisterEventHandler("UnitEnteredCombat",						"OnUnitEnteredCombat", self)
	Apollo.RegisterEventHandler("ChangeWorld", 								"OnChangeWorld", self)
	Apollo.RegisterEventHandler("PlayerCreated", 							"DrawPathAbilityList", self)
	Apollo.RegisterEventHandler("CharacterCreated", 						"DrawPathAbilityList", self)
	Apollo.RegisterEventHandler("UpdatePathXp", 							"DrawPathAbilityList", self)
	Apollo.RegisterEventHandler("AbilityBookChange", 						"DrawPathAbilityList", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 			"OnTutorial_RequestUIAnchor", self)

	Apollo.RegisterTimerHandler("RefreshPathTimer", 						"DrawPathAbilityList", self)
	
	--Load Forms
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "PathFrameForm", "FixedHudStratum", self)
	
	self.wndMenu = Apollo.LoadForm(self.xmlDoc, "PathSelectionMenu", nil, self)
	self.wndMain:FindChild("PathOptionToggle"):AttachWindow(self.wndMenu)
	self.wndMenu:Show(false)
	
	if self.nSelectedPathId then
		local tAbilities = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Path)
		local bIsValidPathId = false
		
		for idx, tAbility in pairs(tAbilities) do
			if tAbility.bIsActive then
				bIsValidPathId = bIsValidPathId or tAbility.nId == self.nSelectedPathId
			end
		end
		
		self.nSelectedPathId = bIsValidPathId and self.nSelectedPathId or nil
	end
	
	self:DrawPathAbilityList()
	return true
end

-----------------------------------------------------------------------------------------------
-- PathFrame Functions
-----------------------------------------------------------------------------------------------
function PathFrame:DrawPathAbilityList()
	if not self.unitPlayer then
		return
	end
	
	local tAbilities = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Path)
	if not tAbilities then
		return	
	end
	
	local wndList = self.wndMenu:FindChild("Content")
	wndList:DestroyChildren()
	
	local nCount = 0
	local nListHeight = 0
	for _, tAbility in pairs(tAbilities) do
		if tAbility.bIsActive then
			local splCurr = tAbility.tTiers[tAbility.nCurrentTier].splObject
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "PathBtn", wndList, self)
			nCount = nCount + 1
			
			self.nSelectedPathId = self.nSelectedPathId and self.nSelectedPathId or tAbility.nId
			
			local nLeft, nTop, nRight, nBottom = wndCurr:GetAnchorOffsets()
			nListHeight = nListHeight + wndCurr:GetHeight()
			wndCurr:FindChild("PathBtnIcon"):SetSprite(splCurr:GetIcon())
			wndCurr:SetData(tAbility.nId)
			if Tooltip and Tooltip.GetSpellTooltipForm then
				wndCurr:SetTooltipDoc(nil)
				Tooltip.GetSpellTooltipForm(self, wndCurr, splCurr)
			end
		end
	end
	
	if self.nSelectedPathId ~= ActionSetLib.GetCurrentActionSet()[10] then
		self:HelperSetPathAbility(self.nSelectedPathId)
	end
	
	self.bHasPathAbilities = nCount > 1
	self.wndMain:Show(nCount > 0)
	self.wndMain:FindChild("PathOptionToggle"):Enable(self.bHasPathAbilities)
	
	local nHeight = wndList:ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = self.wndMenu:GetAnchorOffsets()
	self.wndMenu:SetAnchorOffsets(nLeft, nBottom - (nListHeight + knBottomPadding+knTopPadding), nRight, nBottom)
end

function PathFrame:HelperSetPathAbility(nAbilityId)
	local tActionSet = ActionSetLib.GetCurrentActionSet()
	if not tActionSet or not nAbilityId then
		return false
	end
	
	tActionSet[knPathLASIndex] = nAbilityId
	local tResult = ActionSetLib.RequestActionSetChanges(tActionSet)

	if tResult.eResult ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok then
		return false
	end
	
	
	Event_FireGenericEvent("PathAbilityUpdated", nAbilityId)
	self.nSelectedPathId = nAbilityId
	
	return true
end

-----------------------------------------------------------------------------------------------
-- PathFrameForm Functions
-----------------------------------------------------------------------------------------------
function PathFrame:OnGenerateTooltip(wndControl, wndHandler, tType, arg1, arg2)
	if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
		Tooltip.GetSpellTooltipForm(self, wndControl, arg1)
	end
end

function PathFrame:OnPathOptionToggle(wndHandler, wndControl, eMouseButton)
	if wndControl:IsChecked() then
		self.wndMenu:Show(true)
		self.wndMenu:ToFront()
	else
		self.wndMenu:Show(false)
	end
end

function PathFrame:OnPathBtn(wndControl, wndHandler)
	local result = self:HelperSetPathAbility(wndControl:GetData())
	
	self.nSelectedPathId = result and wndControl:GetData() or nil
	
	self.wndMenu:Show(false)
end

function PathFrame:OnCloseBtn()
	self.wndMenu:Show(false)
end

function PathFrame:OnChangeWorld()
	self.wndMenu:Show(false)
end

function PathFrame:OnUnitEnteredCombat(unit, bIsInCombat)
	if unit ~= self.unitPlayer or not self.wndMain then
		return
	end
	
	self.wndMain:FindChild("PathOptionToggle"):Enable(not bIsInCombat and self.bHasPathAbilities)
end

function PathFrame:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor == GameLib.CodeEnumTutorialAnchor.Path then
		local tRect = {}
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
		
		Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	end
end

-----------------------------------------------------------------------------------------------
-- PathFrame Instance
-----------------------------------------------------------------------------------------------
local PathFrameInst = PathFrame:new()
PathFrameInst:Init()er = self.wndMain:FindChild("PowerMapActiveContainer")

	-- Completion Counting, if necessary
	if tPowerMap.nNeeded > 0 then
		wndPowerMapContainer:FindChild("ProgressText"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), tPowerMap.nCompleted, tPowerMap.nNeeded))
	end
	wndPowerMapContainer:FindChild("PowerMapProgressC"):Show(tPowerMap.nNeeded > 0)

	-- Wait despawn timer, if necessary
	if tPowerMap.bIsWaiting then
		wndPowerMapContainer:FindChild("DespawnText"):SetAML("<P Align=\"Center\">"..self:CalculateMLTimeText(self.nPowerMapDespawnTimer).."</P>")
		wndPowerMapContainer:FindChild("PowerMapProgressFlash"):Show(tPowerMap.nNeeded ~= tPowerMap.nCompleted and tPowerMap.nNeeded > 0)
		wndPowerMapContainer:SetSprite("PlayerPathContent_TEMP:spr_PathExpPowerMapRedBG")
	else
		wndPowerMapContainer:SetSprite("")
		wndPowerMapContainer:FindChild("DespawnText"):SetAML("")
	end
	wndPowerMapContainer:FindChild("PowerMapDespawnC"):Show(tPowerMap.bIsWaiting)
	wndPowerMapContainer:FindChild("PowerMapSignalC"):Show(not tPowerMap.bIsWaiting)


	-- Range Text and Range Finder on Target
	self:PositionPowerMapRangeFinder(self.wndPowerMapRangeFinder, self.wndPowerMapRangeFinder:GetData(), tPowerMap.bIsWaiting, tPowerMap.fRatio)

	--wndPowerMapContainer:ArrangeChildrenVert(1)
end

function PathExplorerMissions:PositionPowerMapRangeFinder(wndPowerMapRangeFinder, unitTarget, bIsWaiting, nRatio)
	if not unitTarget or not unitTarget:GetPosition() then
		return
	end
	wndPowerMapRangeFinder:Show(not self.bTextBubbleShown)
	wndPowerMapRangeFinder:SetUnit(unitTarget, 1) -- TODO 1 is EModelAttachment.ModelAttachment_NAME

	-- Range to target
	posTarget = unitTarget:GetPosition()
	posPlayer = GameLib.GetPlayerUnit():GetPosition()
	local nDistance = math.floor(math.sqrt(math.pow((posTarget.x - posPlayer.x), 2) + math.pow((posTarget.y - posPlayer.y), 2) + math.pow((posTarget.z - posPlayer.z), 2)))
	wndPowerMapRangeFinder:FindChild("RangeFinderText"):SetText(string.format("%s m", nDistance))
	self.wndMain:FindChild("PowerMapContainer"):FindChild("PowerMapRangeText"):SetText(String_GetWeaselString(Apollo.GetString("ExplorerMissions_DistanceNumber"), nDistance))

	-- Color
	local nRatioColor = CColor.new(0, 1, 0, 1)
	local nRatioSprite = "CRB_NameplateSprites:sprNp_HealthBarFriendly"
	if nRatio and nRatio > 0.66 then
		nRatioColor = CColor.new(1, 0, 0, 1)
		nRatioSprite = "CRB_NameplateSprites:sprNp_HealthBarHostile"
	elseif nRatio and nRatio > 0.33 then
		nRatioColor = CColor.new(248/255, 185/255, 54/255, 1)
		nRatioSprite = "CRB_NameplateSprites:sprNp_HealthBarNeutral"
	end
	wndPowerMapRangeFinder:FindChild("RangeFinderText"):SetTextColor(nRatioColor)
	self.wndMain:FindChild("PowerMapContainer"):FindChild("PowerMapRangeText"):SetTextColor(nRatioColor)

	-- Progress Bar
	wndPowerMapRangeFinder:FindChild("RangeFinderProgress"):Show(not bIsWaiting)
	wndPowerMapRangeFinder:FindChild("RangeFinderProgress"):SetProgress(nRatio)
	wndPowerMapRangeFinder:FindChild("RangeFinderProgress"):SetFullSprite(nRatioSprite)

	-- Datachron Progress Bar
	if not bIsWaiting then
		self.wndMain:FindChild("PowerMapContainer"):FindChild("DistanceProgressBar"):SetProgress(nRatio)
		self.wndMain:FindChild("PowerMapContainer"):FindChild("DistanceProgressBar"):SetFullSprite(nRatioSprite)
	end

	-- Despawn Warning
	wndPowerMapRangeFinder:FindChild("RangeFinderDespawnWarning"):Show(bIsWaiting)
end

function PathExplorerMissions:OnExplorerPowerMapWaiting(pmMission, nVictoryDelay