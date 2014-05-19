-----------------------------------------------------------------------------------------------
-- Client Lua Script for RaidFrameTearOff
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local RaidFrameTearOff = {}

local LuaEnumLeaderType =
{
	Leader = 1,
	MainTank = 2,
	MainAssist = 3,
	RaidAssist = 4,
}

local LuaEnumSpriteColor =
{
	Red = 1,
	Orange = 2,
	Green = 3,
}	

local ktIdToRoleSprite =
{
	[-1] = "",
	[MatchingGame.Roles.DPS] = "sprRaid_Icon_RoleDPS",
	[MatchingGame.Roles.Healer] = "sprRaid_Icon_RoleHealer",
	[MatchingGame.Roles.Tank] = "sprRaid_Icon_RoleTank",
}

local ktIdToRoleTooltip =
{
	[-1] = "",
	[MatchingGame.Roles.DPS] = "CRB_DPS",
	[MatchingGame.Roles.Healer] = "CRB_Healer",
	[MatchingGame.Roles.Tank] = "CRB_Tank",
}

local ktIdToLeaderSprite =  -- 0 is valid
{
	[0] = "",
	[LuaEnumLeaderType.Leader] 		= "CRB_Raid:sprRaid_Icon_Leader",
	[LuaEnumLeaderType.MainTank] 	= "CRB_Raid:sprRaid_Icon_TankLeader",
	[LuaEnumLeaderType.MainAssist] 	= "CRB_Raid:sprRaid_Icon_AssistLeader",
	[LuaEnumLeaderType.RaidAssist] 	= "CRB_Raid:sprRaid_Icon_2ndLeader",
}

local ktIdToLeaderTooltip =
{
	[0] = "",
	[LuaEnumLeaderType.Leader] 		= "RaidFrame_RaidLeader",
	[LuaEnumLeaderType.MainTank] 	= "RaidFrame_MainTank",
	[LuaEnumLeaderType.MainAssist] 	= "RaidFrame_MainAssist",
	[LuaEnumLeaderType.RaidAssist] 	= "RaidFrame_CombatAssist",
}

local ktHealthStatusToSpriteSmall =
{
	[LuaEnumSpriteColor.Red] 	= "sprRaid_HealthProgBar_Red",
	[LuaEnumSpriteColor.Orange] = "sprRaid_HealthProgBar_Orange",
	[LuaEnumSpriteColor.Green] 	= "sprRaid_HealthProgBar_Green",
}

local ktHealthStatusToSpriteSmallEdgeGlow =
{
	[LuaEnumSpriteColor.Red] 	= "sprRaid_HealthEdgeGlow_Red",
	[LuaEnumSpriteColor.Orange] = "sprRaid_HealthEdgeGlow_Orange",
	[LuaEnumSpriteColor.Green] 	= "sprRaid_HealthEdgeGlow_Green",
}

local ktHealthStatusToSpriteBig =
{
	[LuaEnumSpriteColor.Red] 	= "sprRaidTear_BigHealthProgBar_Red",
	[LuaEnumSpriteColor.Orange] = "sprRaidTear_BigHealthProgBar_Orange",
	[LuaEnumSpriteColor.Green] 	= "sprRaidTear_BigHealthProgBar_Green",
}

local ktHealthStatusToSpriteBigEdgeGlow =
{
	[LuaEnumSpriteColor.Red] 	= "sprRaidTear_BigHealthEdgeGlow_Red",
	[LuaEnumSpriteColor.Orange] = "sprRaidTear_BigHealthEdgeGlow_Orange",
	[LuaEnumSpriteColor.Green] 	= "sprRaidTear_BigHealthEdgeGlow_Green",
}

local ktDispositionToSprite =
{
	[Unit.CodeEnumDisposition.Neutral] 	= "",
	[Unit.CodeEnumDisposition.Friendly] = "sprRaid_Icon_GreenFriendly",
	[Unit.CodeEnumDisposition.Hostile] 	= "sprRaid_Icon_RedEnemy",
}
-- Set below

function RaidFrameTearOff:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RaidFrameTearOff:Init()
    Apollo.RegisterAddon(self)
end

function RaidFrameTearOff:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	
	local tSaved = 
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		tOptions = self.tSavedOptions,
		nSaveVersion = knSaveVersion,
	}
	
	return tSaved
end

function RaidFrameTearOff:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
	self.tSavedOptions = tSavedData.tOptions
	
end

function RaidFrameTearOff:OnLoad()
	Apollo.RegisterEventHandler("UnitEnteredCombat", 					"OnEnteredCombat", self)
	Apollo.RegisterEventHandler("GenericEvent_Raid_ToggleRaidTearOff", 	"Initialize", self)
	Apollo.RegisterTimerHandler("MainUpdateTimer", 						"MainUpdateTimer", self)
	Apollo.CreateTimer("MainUpdateTimer", 0.5, true)
	Apollo.StopTimer("MainUpdateTimer")

	self.tTrackedMemberIdx = {}
	
	self.tSavedOptions = 
	{
		bLeader 	= true,		-- Leader Icons
		bRole 		= false,	-- Role Icons
		bDebuffs	= false,	-- Debuffs
		bBuffs 		= false,	-- Buffs
		bFocus		= false,	-- Focus
		bToT 		= true,		-- Target Of Leaders
		bAutoLock 	= true,		-- Combat Auto-Locking
	}

	self.nHealthWarn = 0.4
	self.nHealthWarn2 = 0.6
end

function RaidFrameTearOff:Initialize(nMemberIdx)
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("RaidTearOffContainer"):DestroyChildren()
	else
		Apollo.StartTimer("MainUpdateTimer")
		self.wndMain = Apollo.LoadForm("RaidFrameTearOff.xml", "RaidFrameTearOffForm", nil, self)
		
		local wndOptions = self.wndMain:FindChild("RaidTearOffOptions:SelfConfigRaidCustomizeOptions")
		self.wndMain:FindChild("RaidTearOffOptionsBtn"):AttachWindow(self.wndMain:FindChild("RaidTearOffOptions"))
		wndOptions:FindChild("RaidCustomizeLeaderIcons"):SetCheck(self.tSavedOptions.bLeader)
		wndOptions:FindChild("RaidCustomizeRoleIcons"):SetCheck(self.tSavedOptions.bRole)
		wndOptions:FindChild("RaidCustomizeDebuffs"):SetCheck(self.tSavedOptions.bDebuffs)
		wndOptions:FindChild("RaidCustomizeBuffs"):SetCheck(self.tSavedOptions.bBuffs)
		wndOptions:FindChild("RaidCustomizeManaBar"):SetCheck(self.tSavedOptions.bFocus)
		wndOptions:FindChild("RaidCustomizeAssistTargets"):SetCheck(self.tSavedOptions.bToT)
		wndOptions:FindChild("RaidCustomizeLockInCombat"):SetCheck(self.tSavedOptions.bAutoLock)
		
		self.wndMain:Show(true)
	end

	if not nMemberIdx then
		return
	end
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	self.unitPlayerDisposComparison = GameLib.GetPlayerUnit()
	self.tTrackedMemberIdx[nMemberIdx] = nMemberIdx -- Add a member to the tracked list TODO: Remove
	self:MainUpdateTimer()
end

function RaidFrameTearOff:DestroyAndRedrawAllFromUI(wndHandler, wndControl)
	self.wndMain:FindChild("RaidTearOffContainer"):DestroyChildren()
	
	local wndOptions = self.wndMain:FindChild("RaidTearOffOptions:SelfConfigRaidCustomizeOptions")
	self.tSavedOptions =
	{
		bLeader 	= wndOptions:FindChild("RaidCustomizeLeaderIcons"):IsChecked(),
		bRole 		= wndOptions:FindChild("RaidCustomizeRoleIcons"):IsChecked(),
		bDebuffs	= wndOptions:FindChild("RaidCustomizeDebuffs"):IsChecked(),
		bBuffs 		= wndOptions:FindChild("RaidCustomizeBuffs"):IsChecked(),
		bFocus		= wndOptions:FindChild("RaidCustomizeManaBar"):IsChecked(),
		bToT 		= wndOptions:FindChild("RaidCustomizeAssistTargets"):IsChecked(),
		bAutoLock 	= wndOptions:FindChild("RaidCustomizeLockInCombat"):IsChecked(),
	}
	self:MainUpdateTimer()
end

-----------------------------------------------------------------------------------------------
-- Main Methods
-----------------------------------------------------------------------------------------------

function RaidFrameTearOff:MainUpdateTimer()
	if not GroupLib.InRaid() then
		if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsShown() then
			self.wndMain:Show(false)
		end
		return
	end

	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then
		return
	end

	local unitTarget = GameLib.GetTargetUnit()
	for key, nMemberIdx in pairs(self.tTrackedMemberIdx) do
		local tMemberData = GroupLib.GetGroupMember(nMemberIdx)
		if tMemberData then
			self:UpdateSpecificMember(nMemberIdx, tMemberData, unitTarget)
		end
	end

	-- Remove zombie entries
	for idx, wndRaidMember in pairs(self.wndMain:FindChild("RaidTearOffContainer"):GetChildren()) do
		local nFoundMemberIdx = tonumber(wndRaidMember:GetName()) or 0
		if not self.tTrackedMemberIdx[nFoundMemberIdx] then
			wndRaidMember:Destroy()
		end
	end

	if #self.wndMain:FindChild("RaidTearOffContainer"):GetChildren() == 0 then
		Apollo.StopTimer("MainUpdateTimer")
		
		self.wndMain:Destroy()		
		return
	end

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.wndMain:FindChild("RaidTearOffContainer"):ArrangeChildrenVert(0) + 58)
	self.wndMain:SetSizingMinimum(200, self.wndMain:GetHeight())
	self.wndMain:SetSizingMaximum(1000, self.wndMain:GetHeight())
end

function RaidFrameTearOff:UpdateSpecificMember(nMemberIdx, tMemberData, unitTarget)
	local wndRaidMember = self:LoadByName("RaidTearMember", self.wndMain:FindChild("RaidTearOffContainer"), nMemberIdx)
	wndRaidMember:SetSprite("sprRaidTear_BaseHoloBlue")
	wndRaidMember:FindChild("RaidMemberToTFrame"):Show(false)
	wndRaidMember:FindChild("RaidMemberUntearBtn"):Show(false)
	wndRaidMember:FindChild("RaidMemberUntearBtn"):SetData(nMemberIdx)
	wndRaidMember:FindChild("RaidMemberName"):SetText(tMemberData.strCharacterName)

	local bShowRoleIcon = self.wndMain:FindChild("RaidCustomizeRoleIcons"):IsChecked()
	if bShowRoleIcon then
		local nRoleIdx = -1
		if tMemberData.bDPS then
			eRoleIdx = MatchingGame.Roles.DPS
		elseif tMemberData.bHealer then
			eRoleIdx = MatchingGame.Roles.Healer
		elseif tMemberData.bTank then
			eRoleIdx = MatchingGame.Roles.Tank
		end
		wndRaidMember:FindChild("RaidMemberRoleIconSprite"):SetSprite(ktIdToRoleSprite[eRoleIdx])
		wndRaidMember:FindChild("RaidMemberRoleIconSprite"):SetTooltip(Apollo.GetString(ktIdToRoleTooltip[eRoleIdx]))
		self.tSavedOptions.bRole = true
	end
	wndRaidMember:FindChild("RaidMemberRoleIconSprite"):Show(bShowRoleIcon)

	local bShowLeaderIcon = self.wndMain:FindChild("RaidCustomizeLeaderIcons"):IsChecked()
	if bShowLeaderIcon then
		local eLeaderIdx = 0
		if tMemberData.bIsLeader then
			eLeaderIdx = LuaEnumLeaderType.Leader
		elseif tMemberData.bMainTank then
			eLeaderIdx = LuaEnumLeaderType.MainTank
		elseif tMemberData.bMainAssist then
			eLeaderIdx = LuaEnumLeaderType.MainAssist
		elseif tMemberData.bRaidAssistant then
			eLeaderIdx = LuaEnumLeaderType.RaidAssist
		end
		wndRaidMember:FindChild("RaidMemberLeaderIcon"):SetSprite(ktIdToLeaderSprite[eLeaderIdx])
		wndRaidMember:FindChild("RaidMemberLeaderIcon"):SetTooltip(Apollo.GetString(ktIdToLeaderTooltip[eLeaderIdx]))
	end
	wndRaidMember:FindChild("RaidMemberLeaderIcon"):Show(bShowLeaderIcon)

	local bShowManaBar = self.wndMain:FindChild("RaidCustomizeManaBar"):IsChecked()
	if bShowManaBar and tMemberData.nManaMax and tMemberData.nManaMax > 0 then
		local wndManaBar = self:LoadByName("RaidTearManaBar", wndRaidMember, "RaidTearManaBar")
		wndManaBar:SetMax(tMemberData.nManaMax)
		wndManaBar:SetProgress(tMemberData.nMana)
	end

	-- Unit
	local unitCurr = GroupLib.GetUnitForGroupMember(nMemberIdx)
	if unitCurr then
		if unitTarget and unitTarget == unitCurr then
			wndRaidMember:SetSprite("sprRaidTear_BaseHoloBlueBright")
			wndRaidMember:FindChild("RaidMemberUntearBtn"):Show(not self.wndMain:FindChild("RaidLockFrameBtn"):IsChecked())
		end

		-- Target of Target
		if tMemberData.bIsLeader or tMemberData.bMainTank or tMemberData.bMainAssist then
			local unitToT = unitCurr:GetTarget()
			if unitToT and self.wndMain:FindChild("RaidCustomizeAssistTargets"):IsChecked() then
				wndRaidMember:FindChild("RaidMemberToTName"):SetData(unitToT)
				wndRaidMember:FindChild("RaidMemberToTName"):SetText(unitToT:GetName())
				wndRaidMember:FindChild("RaidMemberToTFrame"):SetSprite("CRB_Raid:btnRaidTear_ThinHoloListBtnNormal")
				wndRaidMember:FindChild("RaidMemberAlignIcon"):SetSprite(ktDispositionToSprite[unitToT:GetDispositionTo(self.unitPlayerDisposComparison)])
				self:DoHPAndShieldResizing(wndRaidMember:FindChild("RaidMemberToTVitals"), unitToT)

				if unitTarget and unitTarget == unitToT then
					wndRaidMember:FindChild("RaidMemberToTFrame"):SetSprite("CRB_Raid:btnRaidTear_ThinHoloListBtnPressed")
				end
			end
			wndRaidMember:FindChild("RaidMemberToTFrame"):Show(unitToT and self.wndMain:FindChild("RaidCustomizeAssistTargets"):IsChecked())
		end

		-- Buffs
		if self.wndMain:FindChild("RaidCustomizeBuffs"):IsChecked() then
			wndRaidMember:FindChild("RaidMemberBeneBuffBar"):SetUnit(unitCurr)
		else
			wndRaidMember:FindChild("RaidMemberBeneBuffBar"):SetUnit(nil)
		end
		wndRaidMember:FindChild("RaidMemberBeneBuffBar"):Show(self.wndMain:FindChild("RaidCustomizeBuffs"):IsChecked())

		-- Debuffs
		if self.wndMain:FindChild("RaidCustomizeDebuffs"):IsChecked() then
			wndRaidMember:FindChild("RaidMemberHarmBuffBar"):SetUnit(unitCurr)
		else
			wndRaidMember:FindChild("RaidMemberHarmBuffBar"):SetUnit(nil)
		end
		wndRaidMember:FindChild("RaidMemberHarmBuffBar"):Show(self.wndMain:FindChild("RaidCustomizeDebuffs"):IsChecked())

		self:DoHPAndShieldResizing(wndRaidMember:FindChild("RaidMemberBaseVitals"), unitCurr, true)
	end

	-- Resize
	local nLeft, nTop, nRight, nBottom = wndRaidMember:GetAnchorOffsets()
	if (tMemberData.bIsLeader or tMemberData.bMainTank or tMemberData.bMainAssist) and self.wndMain:FindChild("RaidCustomizeAssistTargets"):IsChecked() then
		wndRaidMember:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 58)
	else
		wndRaidMember:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 42)
	end
end

-----------------------------------------------------------------------------------------------
-- Simple UI interaction
-----------------------------------------------------------------------------------------------

function RaidFrameTearOff:OnCloseBtn(wndHandler, wndControl)
	if self.wndMain and self.wndMain:IsValid() then
		Apollo.StopTimer("MainUpdateTimer")
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
		
		for nMemberIdx, nValue in pairs(self.tTrackedMemberIdx) do
			Event_FireGenericEvent("GenericEvent_Raid_ToggleRaidUnTear", nMemberIdx)
		end
		self.tTrackedMemberIdx = {}
	end
end

function RaidFrameTearOff:OnRaidMemberUntearBtn(wndHandler, wndControl) -- RaidMemberUntearBtn
	local nMemberIdx = wndHandler:GetData()
	if nMemberIdx and self.tTrackedMemberIdx[nMemberIdx] then
		Event_FireGenericEvent("GenericEvent_Raid_ToggleRaidUnTear", nMemberIdx)
		self.tTrackedMemberIdx[nMemberIdx] = nil
		self:MainUpdateTimer()
	end
end

function RaidFrameTearOff:OnRaidLockFrameBtnToggle(wndHandler, wndControl) -- RaidLockFrameBtn
	self.wndMain:SetStyle("Sizable", not wndHandler:IsChecked())
	self.wndMain:SetStyle("Moveable", not wndHandler:IsChecked())
	if wndHandler:IsChecked() then
		self.wndMain:SetSprite("sprRaid_BaseNoArrow")
	else
		self.wndMain:SetSprite("sprRaid_Base")
	end
end

function RaidFrameTearOff:OnRaidTearMemberMouseUp(wndHandler, wndControl) -- RaidTearMember
	if wndHandler ~= wndControl or not wndHandler then
		return
	end

	local unitMember = GroupLib.GetUnitForGroupMember(wndHandler:GetName())
	if unitMember then
		GameLib.SetTargetUnit(unitMember)
		self:MainUpdateTimer()
	end
end

function RaidFrameTearOff:OnRaidMemberToTNameClick(wndHandler, wndControl) -- RaidMemberToTName
	-- GOTCHA: Use MouseUp instead of ButtonCheck/SetSprite to avoid weird edgecase bugs
	if wndHandler ~= wndControl or not wndHandler or not wndHandler:GetData() then
		return
	end

	GameLib.SetTargetUnit(wndHandler:GetData())
	self:MainUpdateTimer()
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function RaidFrameTearOff:OnEnteredCombat(unit, bInCombat)
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsVisible() and unit == GameLib.GetPlayerUnit() and self.wndMain:FindChild("RaidCustomizeLockInCombat"):IsChecked() then
		self.wndMain:FindChild("RaidLockFrameBtn"):SetCheck(bInCombat)
		self:OnRaidLockFrameBtnToggle(self.wndMain:FindChild("RaidLockFrameBtn"), self.wndMain:FindChild("RaidLockFrameBtn"))
	end
end

function RaidFrameTearOff:DoHPAndShieldResizing(wndBtnParent, unitPlayer, bBigSprites)
	if unitPlayer and unitPlayer:GetHealth() then
		local nHealthCurr 	= unitPlayer:GetHealth()
		local nHealthMax 	= unitPlayer:GetMaxHealth()
		local nShieldCurr 	= unitPlayer:GetShieldCapacity()
		local nShieldMax 	= unitPlayer:GetShieldCapacityMax()
		local nAbsorbCurr 	= 0
		local nAbsorbMax 	= unitPlayer:GetAbsorptionMax()

		if nAbsorbMax > 0 then
			nAbsorbCurr = unitPlayer:GetAbsorptionValue() -- Since it doesn't clear when the buff drops off
		end
		local nTotalMax = nHealthMax + nShieldMax + nAbsorbMax

		-- Bars
		wndBtnParent:FindChild("HealthBar"):Show(nHealthCurr > 0 and nHealthMax > 0)
		wndBtnParent:FindChild("MaxAbsorbBar"):Show(nHealthCurr > 0 and nAbsorbMax > 0)
		wndBtnParent:FindChild("MaxShieldBar"):Show(nHealthCurr > 0 and nShieldMax > 0)
		wndBtnParent:FindChild("CurrShieldBar"):Show(nHealthCurr > 0 and nShieldMax > 0)

		wndBtnParent:FindChild("CurrShieldBar"):SetMax(nShieldMax)
		wndBtnParent:FindChild("CurrShieldBar"):SetProgress(nShieldCurr)
		wndBtnParent:FindChild("CurrShieldBar"):EnableGlow((wndBtnParent:FindChild("CurrShieldBar"):GetWidth() * nShieldCurr/nShieldMax) > 4)
		wndBtnParent:FindChild("CurrAbsorbBar"):SetMax(nAbsorbMax)
		wndBtnParent:FindChild("CurrAbsorbBar"):SetProgress(nAbsorbCurr)
		wndBtnParent:FindChild("CurrAbsorbBar"):EnableGlow((wndBtnParent:FindChild("CurrAbsorbBar"):GetWidth() * nAbsorbCurr/nAbsorbMax) > 4)
		wndBtnParent:FindChild("HealthBarEdgeGlow"):Show(nShieldMax <= 0)

		-- Health Bar Coloring
		local nHealthSpriteIdx = LuaEnumSpriteColor.Green
		if (nHealthCurr / nHealthMax) < self.nHealthWarn then
			nHealthSpriteIdx = LuaEnumSpriteColor.Red
		elseif (nHealthCurr / nHealthMax) < self.nHealthWarn2 then
			nHealthSpriteIdx = LuaEnumSpriteColor.Orange
		end

		local tTableToUse = ktHealthStatusToSpriteSmall
		local tTableToUseEdgeGlow = ktHealthStatusToSpriteSmallEdgeGlow
		if bBigSprites then
			tTableToUse = ktHealthStatusToSpriteBig
			tTableToUseEdgeGlow = ktHealthStatusToSpriteBigEdgeGlow
		end
		wndBtnParent:FindChild("HealthBar"):SetSprite(tTableToUse[nHealthSpriteIdx])
		wndBtnParent:FindChild("HealthBar"):FindChild("HealthBarEdgeGlow"):SetSprite(tTableToUseEdgeGlow[nHealthSpriteIdx])

		-- Scaling
		local nWidth = wndBtnParent:GetWidth()
		local nArtOffset = 2
		local nPointHealthRight = nWidth * (nHealthCurr / nTotalMax)
		local nPointShieldRight = nWidth * ((nHealthCurr + nShieldMax) / nTotalMax)
		local nPointAbsorbRight = nWidth * ((nHealthCurr + nShieldMax + nAbsorbMax) / nTotalMax)

		local nLeft, nTop, nRight, nBottom = wndBtnParent:FindChild("HealthBar"):GetAnchorOffsets()
		wndBtnParent:FindChild("HealthBar"):SetAnchorOffsets(nLeft, nTop, nPointHealthRight, nBottom)
		wndBtnParent:FindChild("MaxShieldBar"):SetAnchorOffsets(nPointHealthRight - nArtOffset, nTop, nPointShieldRight, nBottom)
		wndBtnParent:FindChild("MaxAbsorbBar"):SetAnchorOffsets(nPointShieldRight, nTop, nPointAbsorbRight, nBottom)
	end
end

function RaidFrameTearOff:LoadByName(strForm, wndParent, strCustomName)
	local wndNew = wndParent:FindChild(strCustomName)
	if not wndNew then
		wndNew = Apollo.LoadForm("RaidFrameTearOff.xml", strForm, wndParent, self)
		wndNew:SetName(strCustomName)
	end
	return wndNew
end

local RaidFrameTearOffInst = RaidFrameTearOff:new()
RaidFrameTearOffInst:Init()
