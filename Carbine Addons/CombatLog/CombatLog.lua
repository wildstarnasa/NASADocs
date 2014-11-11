-----------------------------------------------------------------------------------------------
-- Client Lua Script for CombatLog
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "Window"
require "Unit"
require "Spell"
require "GameLib"
require "ChatSystemLib"
require "ChatChannelLib"
require "CombatFloater"
require "GroupLib"

local CombatLog = {}
local kstrFontBold 						= "CRB_InterfaceMedium_BB" -- TODO TEMP, allow customizing
local kstrLootColor 					= "ffc0c0c0"
local kstrColorCombatLogOutgoing 		= "ff2f94ac"
local kstrColorCombatLogIncomingGood 	= "ff4bacc6"
local kstrColorCombatLogIncomingBad 	= "ffff4200"
local kstrColorCombatLogPathXP 			= "fffff533"
local kstrColorCombatLogRep 			= "fffff533"
local kstrColorCombatLogXP 				= "fffff533"
local kstrColorCombatLogUNKNOWN 		= "ffffffff"
local kstrCurrencyColor 				= "fffff533"
local kstrStateColor 					= "ff9a8460"
local kstEquipColor 					= "ffc0c0c0"

local knSaveVersion						= 1

function CombatLog:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function CombatLog:Init()
	Apollo.RegisterAddon(self, true, Apollo.GetString("CombatLogOptions_CombatLogBtn"))
end

function CombatLog:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("CombatLog.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function CombatLog:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("CombatLogAbsorption", 				"OnCombatLogAbsorption", self)
	Apollo.RegisterEventHandler("CombatLogCCState", 				"OnCombatLogCCState", self)
	Apollo.RegisterEventHandler("CombatLogCCStateBreak", 			"OnCombatLogCCStateBreak", self)
	Apollo.RegisterEventHandler("CombatLogDamage", 					"OnCombatLogDamage", self)
	Apollo.RegisterEventHandler("CombatLogFallingDamage", 			"OnCombatLogFallingDamage", self)
	Apollo.RegisterEventHandler("CombatLogDelayDeath", 				"OnCombatLogDelayDeath", self)
	Apollo.RegisterEventHandler("CombatLogDispel", 					"OnCombatLogDispel", self)
	Apollo.RegisterEventHandler("CombatLogHeal", 					"OnCombatLogHeal", self)
	Apollo.RegisterEventHandler("CombatLogModifyInterruptArmor", 	"OnCombatLogModifyInterruptArmor", self)
	Apollo.RegisterEventHandler("CombatLogTransference", 			"OnCombatLogTransference", self)
	Apollo.RegisterEventHandler("CombatLogVitalModifier", 			"OnCombatLogVitalModifier", self)
	Apollo.RegisterEventHandler("CombatLogDeflect", 				"OnCombatLogDeflect", self)
	Apollo.RegisterEventHandler("CombatLogImmunity", 				"OnCombatLogImmunity", self)
	Apollo.RegisterEventHandler("CombatLogInterrupted", 			"OnCombatLogInterrupted", self)
	Apollo.RegisterEventHandler("CombatLogKillStreak", 				"OnCombatLogKillStreak", self)
	Apollo.RegisterEventHandler("CombatLogKillPVP", 				"OnCombatLogKillPVP", self)
	Apollo.RegisterEventHandler("CombatLogDeath", 					"OnCombatLogDeath", self)
	Apollo.RegisterEventHandler("CombatLogResurrect", 				"OnCombatLogResurrect", self)
	Apollo.RegisterEventHandler("CombatLogStealth", 				"OnCombatLogStealth", self)
	Apollo.RegisterEventHandler("CombatLogMount", 					"OnCombatLogMount", self)
	Apollo.RegisterEventHandler("CombatLogPet", 					"OnCombatLogPet", self)
	Apollo.RegisterEventHandler("CombatLogExperience", 				"OnCombatLogExperience", self)
	Apollo.RegisterEventHandler("CombatLogEndGameCurrencies", 		"OnCombatLogEndGameCurrencies", self)
	Apollo.RegisterEventHandler("CombatLogElderPointsLimitReached", "OnCombatLogElderPointsLimitReached", self)
	Apollo.RegisterEventHandler("CombatLogDurabilityLoss", 			"OnCombatLogDurabilityLoss", self)
	Apollo.RegisterEventHandler("CombatLogCrafting", 				"OnCombatLogCrafting", self)
	Apollo.RegisterEventHandler("CombatLogModifying", 				"OnCombatLogModifying", self)
	Apollo.RegisterEventHandler("CombatLogItemDestroy", 			"OnCombatLogItemDestroy", self)
	Apollo.RegisterEventHandler("CombatLogLAS",						"OnCombatLogLAS", self)
	Apollo.RegisterEventHandler("CombatLogBuildSwitch",				"OnCombatLogBuildSwitch", self)

	Apollo.RegisterEventHandler("CombatLogString", 					"PostOnChannel", self)
	Apollo.RegisterEventHandler("UpdatePathXp", 					"OnPathExperienceGained", self)
	Apollo.RegisterEventHandler("FactionFloater", 					"OnFactionFloater", self)
	Apollo.RegisterEventHandler("CombatLogLifeSteal", 				"OnCombatLogLifeSteal", self)

	Apollo.RegisterEventHandler("ChangeWorld", 						"OnChangeWorld", self)
	Apollo.RegisterEventHandler("PetSpawned", 						"OnPetStatusUpdated", self)
	Apollo.RegisterEventHandler("PetDespawned", 					"OnPetStatusUpdated", self)
	Apollo.RegisterEventHandler("PlayerEquippedItemChanged", 			"OnPlayerEquippedItemChanged", self)

	self.tTypeMapping =
	{
		[GameLib.CodeEnumDamageType.Physical] 	= Apollo.GetString("DamageType_Physical"),
		[GameLib.CodeEnumDamageType.Tech] 		= Apollo.GetString("DamageType_Tech"),
		[GameLib.CodeEnumDamageType.Magic] 		= Apollo.GetString("DamageType_Magic"),
		[GameLib.CodeEnumDamageType.Fall] 		= Apollo.GetString("DamageType_Fall"),
		[GameLib.CodeEnumDamageType.Suffocate] 	= Apollo.GetString("DamageType_Suffocate"),
		["Unknown"] 							= Apollo.GetString("CombatLog_SpellUnknown"),
		["UnknownDamageType"] 					= Apollo.GetString("CombatLog_SpellUnknown"),
	}

	self.tTypeColor =
	{
		[GameLib.CodeEnumDamageType.Heal] 			= "ff00ff00",
		[GameLib.CodeEnumDamageType.HealShields] 	= "ff00ffae",
	}

	self.crVitalModifier = "ffffffff"
	self.unitPlayer = nil
	self.tPetUnits = {}
	self.timerPetStatusUpdate = ApolloTimer.Create(5.0, false, "TEMP_PetStatusUpdate_HACK", self)
end
function CombatLog:PostOnChannel(strResult)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Combat, string.format("<P Font=\"CRB_InterfaceMedium\">%s</P>", strResult), "")
end

-----------------------------------------------------------------------------------------------
-- Needs Beneficial vs Not Beneficial
-----------------------------------------------------------------------------------------------

function CombatLog:OnCombatLogDamage(tEventArgs)
	-- Example Combat Log Message: 17:18: Alvin uses Mind Stab on Space Pirate for 250 Magic damage (Critical).
	local strDamageColor = self:HelperDamageColor(tEventArgs.eDamageType)
	local tTextInfo = self:HelperCasterTargetSpell(tEventArgs, true, true, true)
	--local strCaster, strTarget, strSpellName, strColor = self:HelperCasterTargetSpell(tEventArgs, true, true, true)

	-- System treats environment damage as coming from the player, so set the caster name and color correctly
	local bEnvironmentDmg = tTextInfo.strCaster == tTextInfo.strTarget
	if bEnvironmentDmg then
		tTextInfo.strColor = kstrColorCombatLogIncomingBad
	end

	tTextInfo.strSpellName = string.format("<T Font=\"%s\">%s</T>", kstrFontBold, tTextInfo.strSpellName)
	local strDamage = string.format("<T TextColor=\"%s\">%s</T>", strDamageColor, tEventArgs.nDamageAmount)

	if tEventArgs.unitTarget and tEventArgs.unitTarget:IsMounted() then
		tTextInfo.strTarget = String_GetWeaselString(Apollo.GetString("CombatLog_MountedTarget"), tTextInfo.strTarget)
	end

	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_BaseSkillUse"), tTextInfo.strCaster, tTextInfo.strSpellName, tTextInfo.strTarget)

	if bEnvironmentDmg then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_EnvironmentDmg"), tTextInfo.strSpellName, tTextInfo.strTarget)
	end

	local strDamageType = Apollo.GetString("CombatLog_UnknownDamageType")
	if tEventArgs.eDamageType then
		strDamageType = self.tTypeMapping[tEventArgs.eDamageType]
	end

	local strDamageMethod = nil
	if tEventArgs.bPeriodic then
		strDamageMethod = Apollo.GetString("CombatLog_PeriodicDamage")
	elseif tEventArgs.eEffectType == Spell.CodeEnumSpellEffectType.DistanceDependentDamage then
		strDamageMethod = Apollo.GetString("CombatLog_DistanceDependent")
	elseif tEventArgs.eEffectType == Spell.CodeEnumSpellEffectType.DistributedDamage then
		strDamageMethod = Apollo.GetString("CombatLog_DistributedDamage")
	else
		strDamageMethod = Apollo.GetString("CombatLog_BaseDamage")
	end

	if strDamageMethod then
		strResult = String_GetWeaselString(strDamageMethod, strResult, strDamage, strDamageType)
	end


	if tEventArgs.nShield and tEventArgs.nShield > 0 then
		local strAmountShielded = string.format("<T TextColor=\"%s\">%s</T>", strDamageColor, tEventArgs.nShield)
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_DamageShielded"), strResult, strAmountShielded)
	end

	if tEventArgs.nAbsorption and tEventArgs.nAbsorption > 0 then
		local strAmountAbsorbed = string.format("<T TextColor=\"%s\">%s</T>", strDamageColor, tEventArgs.nAbsorption)
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_DamageAbsorbed"), strResult, strAmountAbsorbed)
	end

	if tEventArgs.nOverkill and tEventArgs.nOverkill > 0 then
		local strAmountOverkill = string.format("<T TextColor=\"%s\">%s</T>", strDamageColor, tEventArgs.nOverkill)
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_DamageOverkill"), strResult, strAmountOverkill)
	end

	if tEventArgs.bTargetVulnerable then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_DamageVulnerable"), strResult)
	end

	if tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Critical"), strResult)
	end

	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", tTextInfo.strColor, strResult))

	if tEventArgs.bTargetKilled then
		local strKill = String_GetWeaselString(Apollo.GetString("CombatLog_TargetKilled"), tTextInfo.strCaster, tTextInfo.strTarget)
		self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", kstrStateColor, strKill))
	end
end

function CombatLog:OnCombatLogFallingDamage(tEventArgs)
	-- Example Combat Log Message: 17:18: Alvin suffers 246 falling damage
	local strCaster = self:HelperGetNameElseUnknown(tEventArgs.unitCaster)
	local strDamage = string.format("<T TextColor=\"%s\">%s</T>", self:HelperDamageColor(tEventArgs.eDamageType), tEventArgs.nDamageAmount)
	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_FallingDamage"), strCaster, strDamage)
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrColorCombatLogIncomingBad, strResult))
end

function CombatLog:OnCombatLogDeflect(tEventArgs)
	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, true, true)
	tCastInfo.strSpellName = string.format("<T Font=\"%s\">%s</T>", kstrFontBold, tCastInfo.strSpellName)

	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_BaseSkillUse"), tCastInfo.strCaster, tCastInfo.strSpellName, tCastInfo.strTarget)
	strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Deflect"), strResult)

	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", tCastInfo.strColor, strResult))
end

function CombatLog:OnCombatLogImmunity(tEventArgs)
	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, true, true)
	tCastInfo.strSpellName = string.format("<T Font=\"%s\">%s</T>", kstrFontBold, tCastInfo.strSpellName)

	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_BaseSkillUse"), tCastInfo.strCaster, tCastInfo.strSpellName, tCastInfo.strTarget)
	strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Immune"), strResult)

	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", tCastInfo.strColor, strResult))
end

function CombatLog:OnCombatLogDispel(tEventArgs)
	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, true, true)
	tCastInfo.strSpellName = string.format("<T Font=\"%s\">%s</T>", kstrFontBold, tCastInfo.strSpellName)
	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_BaseSkillUse"), tCastInfo.strCaster, tCastInfo.strSpellName, tCastInfo.strTarget)

	local strAppend = Apollo.GetString("CombatLog_DispelSingle")
	if tEventArgs.bRemovesSingleInstance then
		strAppend = Apollo.GetString("CombatLog_DispelMultiple")
	end

	local tSpellCount =
	{
		["name"] = Apollo.GetString("CombatLog_SpellUnknown"),
		["count"] = tEventArgs.nInstancesRemoved
	}

	local strArgRemovedSpellName = tEventArgs.splRemovedSpell:GetName()
	if strArgRemovedSpellName and strArgRemovedSpellName~= "" then
		tSpellCount["name"] = strArgRemovedSpellName
	end

	strResult = String_GetWeaselString(strAppend, strResult, tSpellCount)
	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", tCastInfo.strColor, strResult))
end

function CombatLog:OnCombatLogHeal(tEventArgs)

	local strDamageColor = self:HelperDamageColor(tEventArgs.eDamageType)
	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, true, true)
	tCastInfo.strSpellName = string.format("<T Font=\"%s\">%s</T>", kstrFontBold, tCastInfo.strSpellName)
	local strAmount = string.format("<T TextColor=\"%s\">%s</T>", strDamageColor, tEventArgs.nHealAmount)

	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_BaseSkillUse"), tCastInfo.strCaster, tCastInfo.strSpellName, tCastInfo.strTarget)

	local strHealType = ""
	if tEventArgs.eEffectType == Spell.CodeEnumSpellEffectType.HealShields then
		strHealType = Apollo.GetString("CombatLog_HealShield")
	else
		strHealType = Apollo.GetString("CombatLog_HealHealth")
	end
	strResult = String_GetWeaselString(strHealType, strResult, strAmount)

	if tEventArgs.nOverheal and tEventArgs.nOverheal > 0 then
		local strOverhealAmount = string.format("<T TextColor=\"white\">%s</T>", tEventArgs.nOverheal)
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Overheal"), strResult, strOverhealAmount)
	end

	if tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Critical"), strResult)
	end
	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", tCastInfo.strColor, strResult))
end

function CombatLog:OnCombatLogModifyInterruptArmor(tEventArgs)

	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, true, true)
	tCastInfo.strSpellName = string.format("<T Font=\"%s\">%s</T>", kstrFontBold, tCastInfo.strSpellName)
	local strArmorCount = string.format("<T TextColor=\"white\">%d</T>", tEventArgs.nAmount)

	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_BaseSkillUse"), tCastInfo.strCaster, tCastInfo.strSpellName, tCastInfo.strTarget)
	strResult = String_GetWeaselString(Apollo.GetString("CombatLog_InterruptArmor"), strResult, strArmorCount)
	if tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Critical"), strResult)
	end
	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", tCastInfo.strColor, strResult))
end

function CombatLog:OnCombatLogAbsorption(tEventArgs)
	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, true, true)

	tCastInfo.strSpellName = string.format("<T Font=\"%s\">%s</T>", kstrFontBold, tCastInfo.strSpellName)
	local strDamageColor = self:HelperDamageColor(tEventArgs.eDamageType)
	local strAbsorbAmount = string.format("<T TextColor=\"%s\">%s</T>", strDamageColor, tEventArgs.nAmount)

	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_BaseSkillUse"), tCastInfo.strCaster, tCastInfo.strSpellName, tCastInfo.strTarget)
	strResult = String_GetWeaselString(Apollo.GetString("CombatLog_GrantAbsorption"), strResult, strAbsorbAmount)

	if tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical then
		self:PostOnChannel("Absorption")
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Critical"), strResult)
	end
	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", tCastInfo.strColor, strResult))
end

function CombatLog:OnCombatLogVitalModifier(tEventArgs)
	-- NOTE: strTarget is usually first, but there is no strCaster here
	if not tEventArgs.bShowCombatLog then
		return
	end

	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, true, true)
	local strVital = Apollo.GetString("CombatLog_UnknownVital")
	if tEventArgs.eVitalType then
		strVital = Unit.GetVitalTable()[tEventArgs.eVitalType].strName
	end

	local strValue = string.format("<T TextColor=\"%s\">%s</T>", self.crVitalModifier, tEventArgs.nAmount)

	local strSpellName = string.format("<T Font=\"%s\">%s</T>", kstrFontBold, tCastInfo.strSpellName)
	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_GainVital"), tCastInfo.strTarget, strValue, strVital, strSpellName)

	if tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical then
		self:PostOnChannel("VitalMod")
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Critical"), strResult)
	end
	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", tCastInfo.strColor, strResult))
end

function CombatLog:OnCombatLogCCState(tEventArgs)
	if not self.unitPlayer then
		self.unitPlayer = GameLib.GetControlledUnit()
	end

	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, false)
	if tEventArgs.unitTarget == self.unitPlayer then
		if not tEventArgs.bRemoved then
			local strState = String_GetWeaselString(Apollo.GetString("CombatLog_CCState"), tEventArgs.strState)
			self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", kstrStateColor, strState))
		else
			local strState = String_GetWeaselString(Apollo.GetString("CombatLog_CCFades"), tEventArgs.strState)
			self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", kstrStateColor, strState))
		end
	end

	-- aside from the above text, we only care if this was an add
	if tEventArgs.bRemoved then
		return
	end

	-- display the effects of the cc state
	tCastInfo.strSpellName = string.format("<T Font=\"%s\">%s</T>", kstrFontBold, tEventArgs.splCallingSpell:GetName())
	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_BaseSkillUse"), tCastInfo.strCaster, tCastInfo.strSpellName, tCastInfo.strTarget)

	if tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Stacking_DoesNotStack then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_CCDoesNotStack"), strResult, tEventArgs.strState)
	elseif tEventArgs.eResult == CombatFloater.CodeEnumCCStateApplyRulesResult.Target_Immune then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_CCImmune"), strResult)
	else
		local strEffect = string.format("<T TextColor=\"white\">%s</T>", tEventArgs.strState)
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_CCSideEffect"), strResult, strEffect)
	end

	if tEventArgs.nInterruptArmorHit > 0 and tEventArgs.unitTarget and tEventArgs.unitTarget:GetInterruptArmorValue() > 0 then
		local strAmount = string.format("<T TextColor=\"white\">-%s</T>", tEventArgs.nInterruptArmorHit)
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_InterruptArmorRemoved"), strResult, strAmount)
	end

	local nRemainingIA = tEventArgs.unitTarget and tEventArgs.unitTarget:GetInterruptArmorValue() - tEventArgs.nInterruptArmorHit or -1
	if nRemainingIA >= 0 then
		local strAmount = string.format("<T TextColor=\"white\">%s</T>", nRemainingIA)
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_InterruptArmorLeft"), strResult, strAmount)
	end

	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", self:HelperPickColor(tEventArgs), strResult))
end

-----------------------------------------------------------------------------------------------
-- Special
-----------------------------------------------------------------------------------------------
function CombatLog:OnCombatLogLifeSteal(tEventArgs)
	local strResult = String_GetWeaselString(Apollo.GetString("CombatLogLifesteal"), tEventArgs.unitCaster:GetName(), tEventArgs.nHealthStolen)
	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", self:HelperPickColor(tEventArgs), strResult))
end

function CombatLog:OnCombatLogTransference(tEventArgs)
	if not self.unitPlayer then
		self.unitPlayer = GameLib.GetControlledUnit()
	end

	local bDisableOtherPlayers = Apollo.GetConsoleVariable("cmbtlog.disableOtherPlayers")
	
	-- OnCombatLogDamage does exactly what we need so just pass along the tEventArgs
	if not bDisableOtherPlayers or self.unitPlayer == tEventArgs.unitCaster then
		self:OnCombatLogDamage(tEventArgs)
	end
	
	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, false)
	-- healing data is stored in a table where each subtable contains a different vital that was healed
	for _, tHeal in ipairs(tEventArgs.tHealData) do
		if not bDisableOtherPlayers or self.unitPlayer == tHeal.unitHealed then
			local strVital = Apollo.GetString("CombatLog_UnknownVital")
			if tHeal.eVitalType then
				strVital = Unit.GetVitalTable()[tHeal.eVitalType].strName
			end
			
			-- units in caster's group can get healed
			if tHeal.unitHealed ~= tEventArgs.unitCaster then
				tCastInfo.strTarget = tCastInfo.strCaster
				tCastInfo.strCaster = self:HelperGetNameElseUnknown(tHeal.unitHealed)
			end

			local strAmount = string.format("<T TextColor=\"%s\">%s</T>", self.crVitalModifier, tHeal.nHealAmount)
			local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_GainVital"), tCastInfo.strCaster, strAmount, strVital, tCastInfo.strTarget)

			if tHeal.nOverheal and tHeal.nOverheal > 0 then
				local strOverhealString = ""
				if tHeal.eVitalType == GameLib.CodeEnumVital.ShieldCapacity then
					strOverhealString = Apollo.GetString("CombatLog_Overshield")
				else
					strOverhealString = Apollo.GetString("CombatLog_Overheal")
				end
				strAmount = string.format("<T TextColor=\"white\">%s</T>", tHeal.nOverheal)
				strResult = String_GetWeaselString(strOverhealString, strResult, strAmount)
			end

			if tEventArgs.eCombatResult == GameLib.CodeEnumCombatResult.Critical then
				strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Critical"), strResult)
			end

			-- TODO: Analyze if we can refactor (this has no spell)
			local strColor = kstrColorCombatLogIncomingGood
			if tEventArgs.unitCaster ~= self.unitPlayer then
				strColor = kstrColorCombatLogOutgoing
			end
			self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", strColor, strResult))
		end
	end
end

function CombatLog:OnCombatLogInterrupted(tEventArgs)
	if not tEventArgs or not tEventArgs.unitCaster then
		return
	end

	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, true)
	tCastInfo.strSpellName = string.format("<T Font=\"%s\">%s</T>", kstrFontBold, tCastInfo.strSpellName)
	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_TargetInterrupted"), tCastInfo.strTarget, tCastInfo.strSpellName) -- NOTE: strTarget is first, usually strCaster is first

	if tEventArgs.unitCaster ~= tEventArgs.unitTarget then
		if tEventArgs.splInterruptingSpell and tEventArgs.splInterruptingSpell:GetName() then
			strResult = String_GetWeaselString(Apollo.GetString("CombatLog_InterruptSourceCaster"), strResult, tEventArgs.unitCaster:GetName(), tEventArgs.splInterruptingSpell:GetName())
		else
			strResult = String_GetWeaselString(Apollo.GetString("CombatLog_InterruptSource"), strResult, tEventArgs.unitCaster:GetName())
		end
	elseif tEventArgs.strCastResult and tEventArgs.strCastResult ~= "" then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_InterruptSelf"), strResult, tEventArgs.strCastResult)
	end

	-- TODO: Analyze if we can refactor (this has a unique spell)
	local strColor = kstrColorCombatLogIncomingGood
	if tEventArgs.unitCaster == self.unitPlayer then
		strColor = kstrColorCombatLogOutgoing
	end
	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", strColor, strResult))
end

function CombatLog:OnCombatLogKillStreak(tEventArgs)
	if tEventArgs.nStreakAmount <= 1 then
		return
	end

	local strCaster = self:HelperGetNameElseUnknown(tEventArgs.unitCaster)
	local strResult = Apollo.GetString("CombatLog_Achieves")
	local strStreakType = ""
	if tEventArgs.eStatType == CombatFloater.CodeEnumCombatMomentum.Impulse then
		strStreakType = String_GetWeaselString(Apollo.GetString("CombatLog_ImpulseStreak"), tEventArgs.nStreakAmount)
	else
		if tEventArgs.nStreakAmount == 2 then
			strStreakType = Apollo.GetString("CombatLog_DoubleKill")
		elseif tEventArgs.nStreakAmount == 3 then
			strStreakType = Apollo.GetString("CombatLog_TripleKill")
		else
			strStreakType = String_GetWeaselString(Apollo.GetString("CombatLog_MultiKill"), tEventArgs.nStreakAmount)
		end
	end
	strResult = String_GetWeaselString(strResult, strCaster, strStreakType)

	-- TODO: Analyze if we can refactor (this has no spell and uses default)
	if tEventArgs.unitCaster == self.unitPlayer then
		self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", kstrColorCombatLogOutgoing, strResult))
	else
		self:PostOnChannel(strResult)
	end
end

function CombatLog:OnCombatLogKillPVP(tEventArgs)
	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, true, false)
	self:PostOnChannel(String_GetWeaselString(Apollo.GetString("CombatLog_KillAssist"), tCastInfo.strCaster, tCastInfo.strTarget))
end

-----------------------------------------------------------------------------------------------
-- State Changes (uses color kstrStateColor, dark orange)
-----------------------------------------------------------------------------------------------

function CombatLog:OnCombatLogCCStateBreak(tEventArgs)
	local strBreak = String_GetWeaselString(Apollo.GetString("CombatLog_CCBroken"), tEventArgs.strState)
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrStateColor, strBreak))
end

function CombatLog:OnCombatLogDelayDeath(tEventArgs)
	local tCastInfo = self:HelperCasterTargetSpell(tEventArgs, false, true)
	local strSaved = String_GetWeaselString(Apollo.GetString("CombatLog_NotDeadYet"), tCastInfo.strCaster, tCastInfo.strSpellName)
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrStateColor, strSaved))
end

function CombatLog:OnCombatLogDeath(tEventArgs)
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrStateColor, Apollo.GetString("CombatLog_Death")))
end

function CombatLog:OnCombatLogStealth(tEventArgs)
	local strResult = ""
	if tEventArgs.bExiting then
		strResult = Apollo.GetString("CombatLog_LeaveStealth")
	else
		strResult = Apollo.GetString("CombatLog_EnterStealth")
	end
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrStateColor, strResult))
end

function CombatLog:OnCombatLogMount(tEventArgs)
	local strResult = ""
	if tEventArgs.bDismounted then
		strResult = Apollo.GetString("CombatLog_Dismount")
	else
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Summon"), self:HelperGetNameElseUnknown(tEventArgs.unitTarget))
	end
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrStateColor, strResult))
end

function CombatLog:OnCombatLogPet(tEventArgs)
	local strResult = ""
	local strTarget = self:HelperGetNameElseUnknown(tEventArgs.unitTarget)
	if tEventArgs.bDismissed then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_DismissPet"), strTarget)
	elseif tEventArgs.bKilled then
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_TargetDies"), strTarget)
	else
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Summon"), strTarget)
	end
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrStateColor, strResult))
end

function CombatLog:OnCombatLogResurrect(tEventArgs)
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrStateColor, Apollo.GetString("CombatLog_Resurrect")))
end

function CombatLog:OnCombatLogLAS(tEventArgs)
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrStateColor, Apollo.GetString("CombatLog_LAS")))
end

function CombatLog:OnCombatLogBuildSwitch(tEventArgs)
	local strBuildSwitch = String_GetWeaselString(Apollo.GetString("CombatLog_BuildSwitch"), tEventArgs.nNewSpecIndex)
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrStateColor, strBuildSwitch))
end

-----------------------------------------------------------------------------------------------
-- Loot Experience Colors (Bright Yellow)
-----------------------------------------------------------------------------------------------

function CombatLog:OnCombatLogExperience(tEventArgs)
	if tEventArgs.nXP > 0 then
		local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_XPGain"), tEventArgs.nXP)
		self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrColorCombatLogXP, strResult))
	end

	if tEventArgs.nRestXP > 0 then
		local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_RestXPGain"), tEventArgs.nRestXP)
		self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrColorCombatLogXP, strResult))
	end

	if tEventArgs.nElderPoints > 0 then
		local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_ElderPointsGained"), tEventArgs.nElderPoints)
		self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrColorCombatLogXP, strResult))
	end

	if tEventArgs.nRestEP > 0 then
		local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_RestEPGain"), tEventArgs.nRestEP)
		self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrColorCombatLogXP, strResult))
	end
end

function CombatLog:OnCombatLogEndGameCurrencies(tEventArgs)
	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_LootReceived"), tEventArgs.monLoot:GetMoneyString())
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrCurrencyColor, strResult))
end

function CombatLog:OnCombatLogElderPointsLimitReached(tEventArgs)
	local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_ElderPointLimitReached"))
	self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrColorCombatLogXP, strResult))
end


function CombatLog:OnCombatLogDurabilityLoss(tEventArgs)
	if not self.unitPlayer then
		self.unitPlayer = GameLib.GetControlledUnit()
	end

	if tEventArgs.unitCaster ~= self.unitPlayer then
		local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_DurabilityLoss"), tEventArgs.nAmount)
		self:PostOnChannel(string.format("<P TextColor=\"%s\">%s</P>", kstrLootColor, strResult))
	end
end

-----------------------------------------------------------------------------------------------
-- Old Events
-----------------------------------------------------------------------------------------------

function CombatLog:OnPathExperienceGained(nAmount, strText)
	if nAmount > 0 then
		local strAmount = string.format("<T TextColor=\"ffffffff\">%s</T>", nAmount)
		local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_PathXPGained"), strAmount)

		self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", kstrColorCombatLogPathXP, strResult))
	end
end

function CombatLog:OnFactionFloater(unitTarget, pstrMessage, nAmount, strFactionName, nFactionId) -- Reputation Floater
	if nAmount > 0 then
		strFactionName = string.format("<T TextColor=\"ffffffff\">%s</T>", strFactionName)
		local strAmount = string.format("<T TextColor=\"ffffffff\">%s</T>", nAmount)

		local strResult = String_GetWeaselString(Apollo.GetString("CombatLog_RepGained"), strFactionName, strAmount)

		self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", kstrColorCombatLogRep, strResult))
	end
end

function CombatLog:OnPetStatusUpdated()
	self.timerPetStatusUpdate:Set(1.0, false)
end

function CombatLog:TEMP_PetStatusUpdate_HACK()
	self.tPetUnits = GameLib.GetPlayerPets()
end

function CombatLog:OnChangeWorld()
	self.unitPlayer = GameLib.GetControlledUnit()
end

function CombatLog:OnPlayerEquippedItemChanged(nEquippedSlot, itemNew, itemOld)
	local strResult = ""
	if not itemNew then --unequipping only
		local strOldItemName = itemOld:GetName()
		local strOldItemTypeName = itemOld:GetItemTypeName()
		strResult = String_GetWeaselString(Apollo.GetString("CombatLog_UnEquip"), strOldItemName, strOldItemTypeName)
	else
		local strNewItemName = itemNew:GetName()
		local strNewItemTypeName = itemNew:GetItemTypeName()
		if itemOld then --equipping an item and replacing
			local strPrevItemName = itemOld:GetName()
			strResult = String_GetWeaselString(Apollo.GetString("CombatLog_EquipReplace"), strNewItemName, strPrevItemName, strNewItemTypeName)
		else --just equipping an item
			strResult = String_GetWeaselString(Apollo.GetString("CombatLog_Equip"), strNewItemName, strNewItemTypeName)
		end
	end
	self:PostOnChannel(string.format("<T TextColor=\"%s\">%s</T>", kstEquipColor, strResult))

end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function CombatLog:HelperCasterTargetSpell(tEventArgs, bTarget, bSpell, bColor)
	local tInfo =
	{
		strCaster = nil,
		strTarget = nil,
		strSpellName = nil,
		strColor = nil
	}

	tInfo.strCaster = self:HelperGetNameElseUnknown(tEventArgs.unitCaster)
	if tEventArgs.unitCasterOwner and tEventArgs.unitCasterOwner:GetName() then
		tInfo.strCaster = string.format("%s (%s)", tInfo.strCaster, tEventArgs.unitCasterOwner:GetName())
	end

	if bTarget then
		tInfo.strTarget = self:HelperGetNameElseUnknown(tEventArgs.unitTarget)
		if tEventArgs.unitTargetOwner and tEventArgs.unitTargetOwner:GetName() then
			tInfo.strTarget = string.format("%s (%s)", tInfo.strTarget, tEventArgs.unitTargetOwner:GetName())
		end

		if bColor then
			tInfo.strColor = self:HelperPickColor(tEventArgs)
		end
	end

	if bSpell then
		tInfo.strSpellName = self:HelperGetNameElseUnknown(tEventArgs.splCallingSpell)
	end

	return tInfo
end

function CombatLog:HelperGetNameElseUnknown(nArg)
	if nArg and nArg:GetName() then
		return nArg:GetName()
	end
	return Apollo.GetString("CombatLog_SpellUnknown")
end

function CombatLog:HelperDamageColor(nArg)
	if nArg and self.tTypeColor[nArg] then
		return self.tTypeColor[nArg]
	end
	return kstrColorCombatLogUNKNOWN
end

function CombatLog:HelperPickColor(tEventArgs)
	if not self.unitPlayer then
		self.unitPlayer = GameLib.GetControlledUnit()
	end

	-- Try player matching first
	if tEventArgs.unitCaster == self.unitPlayer then
		return kstrColorCombatLogOutgoing
	elseif tEventArgs.unitTarget == self.unitPlayer and tEventArgs.splCallingSpell and tEventArgs.splCallingSpell:IsBeneficial() then
		return kstrColorCombatLogIncomingGood
	elseif tEventArgs.unitTarget == self.unitPlayer then
		return kstrColorCombatLogIncomingBad
	end

	-- Try pets second
	for idx, tPetUnit in pairs(self.tPetUnits) do
		if tEventArgs.unitCaster == tPetUnit then
			return kstrColorCombatLogOutgoing
		elseif tEventArgs.unitTarget == tPetUnit and tEventArgs.splCallingSpell and tEventArgs.splCallingSpell:IsBeneficial() then
			return kstrColorCombatLogIncomingGood
		elseif tEventArgs.unitTarget == tPetUnit then
			return kstrColorCombatLogIncomingBad
		end
	end

	return kstrColorCombatLogUNKNOWN
end

---------------------------------------------------------------------------------------------------
-- CombatLogOptions
---------------------------------------------------------------------------------------------------

function CombatLog:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local locWindowLocation = self.wndOptions and self.wndOptions:GetLocation() or self.locSavedOptionsLoc

	local tSaved =
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSavedVersion = knSaveVersion,
	}

	return tSaved
end

function CombatLog:OnRestore(eType, tSavedData)
	if tSavedData and tSavedData.nSavedVersion == knSaveVersion then
		if tSavedData.tWindowLocation then
			self.locSavedOptionsLoc = WindowLocation.new(tSavedData.tWindowLocation)
		end
	end
end

function CombatLog:OnConfigure()
	if self.wndOptions == nil or not self.wndOptions:IsValid() then
		self:InitOptions()
	end

	self.wndOptions:Show(true)
	self.wndOptions:ToFront()

	for idx, tControlData in pairs(self.mapOptionsControls) do
		tControlData.wnd:SetData(tControlData)
		tControlData.wnd:SetCheck(not Apollo.GetConsoleVariable(tControlData.consoleVar))
	end
end

function CombatLog:InitOptions()
	self.wndOptions = Apollo.LoadForm(self.xmlDoc, "CombatLogForm", nil, self)
	Apollo.LoadForm(self.xmlDoc, "CombatLogOptionsControls", self.wndOptions:FindChild("ContentMain"), self)
	if self.locSavedOptionsLoc then
		self.wndOptions:MoveToLocation(self.locSavedOptionsLoc)
	end
	self.wndOptions:Show(false)

	self.mapOptionsControls =
	{
		{
			wnd = self.wndOptions:FindChild("EnableOtherPlayers"),
			consoleVar = "cmbtlog.disableOtherPlayers",
		},
		{
			wnd = self.wndOptions:FindChild("EnableAbsorption"),
			consoleVar = "cmbtlog.disableAbsorption",
		},
		{
			wnd = self.wndOptions:FindChild("EnableCCState"),
			consoleVar = "cmbtlog.disableCCState",
		},
		{
			wnd = self.wndOptions:FindChild("EnableDamage"),
			consoleVar = "cmbtlog.disableDamage",
		},
		{
			wnd = self.wndOptions:FindChild("EnableDeflect"),
			consoleVar = "cmbtlog.disableDeflect",
		},
		{
			wnd = self.wndOptions:FindChild("EnableDelayDeath"),
			consoleVar = "cmbtlog.disableDelayDeath",
		},
		{
			wnd = self.wndOptions:FindChild("EnableDispel"),
			consoleVar = "cmbtlog.disableDispel",
		},
		{
			wnd = self.wndOptions:FindChild("EnableFallingDamage"),
			consoleVar = "cmbtlog.disableFallingDamage",
		},
		{
			wnd = self.wndOptions:FindChild("EnableHeal"),
			consoleVar = "cmbtlog.disableHeal",
		},
		{
			wnd = self.wndOptions:FindChild("EnableImmunity"),
			consoleVar = "cmbtlog.disableImmunity",
		},
		{
			wnd = self.wndOptions:FindChild("EnableInterrupted"),
			consoleVar = "cmbtlog.disableInterrupted",
		},
		{
			wnd = self.wndOptions:FindChild("EnableModifyInterruptArmor"),
			consoleVar = "cmbtlog.disableModifyInterruptArmor",
		},
		{
			wnd = self.wndOptions:FindChild("EnableTransference"),
			consoleVar = "cmbtlog.disableTransference",
		},
		{
			wnd = self.wndOptions:FindChild("EnableVitalModifier"),
			consoleVar = "cmbtlog.disableVitalModifier",
		},
		{
			wnd = self.wndOptions:FindChild("EnableDeath"),
			consoleVar = "cmbtlog.disableDeath",
		},
	}
end

function CombatLog:OnMappedOptionsCheckbox(wndHandler, wndControl, eMouseButton)
	local tData = wndControl:GetData()
	Apollo.SetConsoleVariable(tData.consoleVar, not wndControl:IsChecked())
end

function CombatLog:OnCancel(wndHandler, wndControl, eMouseButton)
	self.wndOptions:Show(false)
end

function CombatLog:OnOK(wndHandler, wndControl, eMouseButton)
	self.wndOptions:Show(false)
end

local CombatLogInstance = CombatLog:new()
CombatLog:Init()

