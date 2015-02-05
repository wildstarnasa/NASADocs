-----------------------------------------------------------------------------------------------
-- Client Lua Script for ClassResources
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local ClassResources = {}

local knSaveVersion = 1

function ClassResources:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ClassResources:Init()
    Apollo.RegisterAddon(self, nil, nil, {"ActionBarFrame"})
end

function ClassResources:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ClassResources.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

	Apollo.RegisterEventHandler("ActionBarLoaded", "OnRequiredFlagsChanged", self)
end

function ClassResources:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSave =
	{
		bShowPet = self.bShowPet,
		nSaveVersion = knSaveVersion,
	}

	return tSave
end

function ClassResources:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	self.bShowPet = tSavedData.bShowPet
end

function ClassResources:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	self.bDocLoaded = true
	self:OnRequiredFlagsChanged()
end

function ClassResources:OnRequiredFlagsChanged()
	if g_wndActionBarResources and self.bDocLoaded then
		if GameLib.GetPlayerUnit() then
			self:OnCharacterCreated()
		else
			Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
		end
	end
end

function ClassResources:OnCharacterCreated()
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	end

	local eClassId =  unitPlayer:GetClassId()
	if eClassId == GameLib.CodeEnumClass.Engineer then
		self:OnCreateEngineer()
	elseif unitPlayer:GetClassId() == GameLib.CodeEnumClass.Esper then
		self:OnCreateEsper()
	elseif unitPlayer:GetClassId() == GameLib.CodeEnumClass.Spellslinger then
		self:OnCreateSlinger()
	elseif unitPlayer:GetClassId() == GameLib.CodeEnumClass.Medic then
		self:OnCreateMedic()
	elseif unitPlayer:GetClassId() == GameLib.CodeEnumClass.Warrior then
		self:OnCreateWarrior()
	elseif unitPlayer:GetClassId() == GameLib.CodeEnumClass.Stalker then
		self:OnCreateStalker()
	end
end

-----------------------------------------------------------------------------------------------
-- Esper
-----------------------------------------------------------------------------------------------

function ClassResources:OnCreateEsper()
	Apollo.RegisterEventHandler("VarChange_FrameCount", 		"OnEsperUpdateTimer", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 			"OnEsperEnteredCombat", self)
	Apollo.RegisterTimerHandler("EsperOutOfCombatFade", 		"OnEsperOutOfCombatFade", self)
	self.timerEsperOutOfCombatFade = ApolloTimer.Create(0.5, false, "OnEsperOutOfCombatFade", self)
	self.timerEsperOutOfCombatFade:Stop()

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "EsperResourceForm", g_wndActionBarResources, self)
	self.wndMain:ToFront()

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop, true)

	self.tWindowMap =
	{
		["ComboNumber"]					=	self.wndMain:FindChild("ComboNumber"),
		["ComboBits"]					=	self.wndMain:FindChild("ComboBits"),
		["ComboBits:ComboSolid1"]		=	self.wndMain:FindChild("ComboBits:ComboSolid1"),
		["ComboBits:ComboSolid2"]		=	self.wndMain:FindChild("ComboBits:ComboSolid2"),
		["ComboBits:ComboSolid3"]		=	self.wndMain:FindChild("ComboBits:ComboSolid3"),
		["ComboBits:ComboSolid4"]		=	self.wndMain:FindChild("ComboBits:ComboSolid4"),
		["ComboBits:ComboSolid5"]		=	self.wndMain:FindChild("ComboBits:ComboSolid5"),
		["InnateActiveGlowTop"]			=	self.wndMain:FindChild("InnateActiveGlowTop"),
		["InnateActiveGlowFrame"]		=	self.wndMain:FindChild("InnateActiveGlowFrame"),
		["InnateActiveGlowBottom"]		=	self.wndMain:FindChild("InnateActiveGlowBottom"),
		["ManaProgressBar"]				=	self.wndMain:FindChild("ManaProgressBar"),
		["ManaProgressText"]			=	self.wndMain:FindChild("ManaProgressText"),
		["ManaProgressCover"]			=	self.wndMain:FindChild("ManaProgressCover"),
		["EsperBaseFrame_InCombat"]		=	self.wndMain:FindChild("EsperBaseFrame_InCombat"),
		["EsperOutOfCombatFade"]		=	self.wndMain:FindChild("EsperOutOfCombatFade"),
	}

	self.tWindowMap["EsperBaseFrame_InCombat"]:Show(false, true)

	self.bLastInCombat = nil
	self.nComboCurrent = nil
	self.bInnate = nil
	self.nLastMana = nil
	self.nFadeLevel = 0
	self.xmlDoc = nil
end

function ClassResources:OnEsperUpdateTimer()
	local unitPlayer = GameLib.GetPlayerUnit()
	local nComboCurrent = unitPlayer:GetResource(1)
	local nManaMax = math.floor(unitPlayer:GetMaxMana())
	local nManaCurrent = math.floor(unitPlayer:GetMana())
	local bInnate = GameLib.IsCurrentInnateAbilityActive()
	if self.bLastInCombat == bInCombat and self.nComboCurrent == nComboCurrent and self.bInnate == bInnate and self.nLastMana == nManaCurrent then
		return
	end
	self.bLastInCombat = bInCombat
	self.nComboCurrent = nComboCurrent
	self.bInnate = bInnate
	self.nLastMana = nManaCurrent

	-- Mana
	self.tWindowMap["ManaProgressBar"]:SetMax(nManaMax)
	self.tWindowMap["ManaProgressBar"]:SetProgress(nManaCurrent)
	self.tWindowMap["ManaProgressBar"]:SetTooltip(String_GetWeaselString(Apollo.GetString("EsperResource_FocusTooltip"), nManaCurrent, nManaMax))
	self.tWindowMap["ManaProgressText"]:SetText(nManaCurrent == nManaMax and "" or (math.floor(nManaCurrent / nManaMax * 100).."%"))

	-- Combo Points
	local strInCombat = unitPlayer:IsInCombat() and "CM_EsperSprites:sprEsper_ComboNumPurple_" or "CM_EsperSprites:sprEsper_ComboNumDull_"
	self.tWindowMap["ComboNumber"]:SetSprite(strInCombat..nComboCurrent)
	self.tWindowMap["ComboBits:ComboSolid1"]:Show(nComboCurrent >= 1)
	self.tWindowMap["ComboBits:ComboSolid2"]:Show(nComboCurrent >= 2)
	self.tWindowMap["ComboBits:ComboSolid3"]:Show(nComboCurrent >= 3)
	self.tWindowMap["ComboBits:ComboSolid4"]:Show(nComboCurrent >= 4)
	self.tWindowMap["ComboBits:ComboSolid5"]:Show(nComboCurrent >= 5)

	-- Innate
	if bInnate and not self.tWindowMap["InnateActiveGlowTop"]:GetData() then
		self.tWindowMap["InnateActiveGlowTop"]:SetData(true)
		self.tWindowMap["InnateActiveGlowTop"]:SetSprite("sprEsper_Anim_OuterGlow_Top")
		self.tWindowMap["InnateActiveGlowFrame"]:SetSprite("sprEsper_Anim_OuterGlow_Frame")
		self.tWindowMap["InnateActiveGlowBottom"]:SetSprite("sprEsper_Anim_OuterGlow_Bottom")
	elseif not bInnate then
		self.tWindowMap["InnateActiveGlowTop"]:SetData(false)
	end
end

function ClassResources:OnEsperEnteredCombat(unitPlayer, bInCombat)
	if unitPlayer ~= GameLib.GetPlayerUnit() or not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if bInCombat then
		self.tWindowMap["ManaProgressCover"]:Show(true)
		self.tWindowMap["EsperBaseFrame_InCombat"]:Show(true)

		self.nFadeLevel = 0
		for idx, wndCurr in pairs(self.tWindowMap["ComboBits"]:GetChildren()) do
			wndCurr:SetBGColor(ApolloColor.new(1, 1, 1, 1))
		end
		self.timerEsperOutOfCombatFade:Stop()
	else
		for idx, wndCurr in pairs(self.tWindowMap["ComboBits"]:GetChildren()) do
			wndCurr:SetBGColor(ApolloColor.new(1, 1, 1, 0.5))
		end
		self.tWindowMap["ManaProgressCover"]:Show(false)
		self.tWindowMap["EsperBaseFrame_InCombat"]:Show(false)
		self.timerEsperOutOfCombatFade:Start()
	end
end

function ClassResources:OnEsperOutOfCombatFade()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.nFadeLevel = self.nFadeLevel + 1
	for idx, wndCurr in pairs(self.tWindowMap["ComboBits"]:GetChildren()) do
		wndCurr:SetBGColor(ApolloColor.new(1, 1, 1, 0.5 - (0.025 * self.nFadeLevel)))
	end

	if self.nFadeLevel < 20 then
		self.timerEsperOutOfCombatFade:Start()
	end
end

-----------------------------------------------------------------------------------------------
-- Spellslinger
-----------------------------------------------------------------------------------------------

function ClassResources:OnCreateSlinger()
	Apollo.RegisterEventHandler("VarChange_FrameCount", 		"OnSlingerUpdateTimer", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 			"OnSlingerEnteredCombat", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "SlingerResourceForm", g_wndActionBarResources, self)
	self.wndMain:ToFront()

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop, true)

	self.tWindowMap =
	{
		["LargeSurgeGlow"]				=	self.wndMain:FindChild("LargeSurgeGlow"),
		["LargeSurgeSigil"]				=	self.wndMain:FindChild("LargeSurgeSigil"),
		["SlingerBaseFrame_InCombat"]	=	self.wndMain:FindChild("SlingerBaseFrame_InCombat"),
		["SlingerNode1"]				=	self.wndMain:FindChild("SlingerNode1"),
		["SlingerNode1:NodeRed"]		=	self.wndMain:FindChild("SlingerNode1:NodeRed"),
		["SlingerNode1:NodeFlash"]		=	self.wndMain:FindChild("SlingerNode1:NodeFlash"),
		["SlingerNode1:NodeFilled"]		=	self.wndMain:FindChild("SlingerNode1:NodeFilled"),
		["SlingerNode1:NodeProgress"]	=	self.wndMain:FindChild("SlingerNode1:NodeProgress"),
		["SlingerNode2"]				=	self.wndMain:FindChild("SlingerNode2"),
		["SlingerNode2:NodeRed"]		=	self.wndMain:FindChild("SlingerNode2:NodeRed"),
		["SlingerNode2:NodeFlash"]		=	self.wndMain:FindChild("SlingerNode2:NodeFlash"),
		["SlingerNode2:NodeFilled"]		=	self.wndMain:FindChild("SlingerNode2:NodeFilled"),
		["SlingerNode2:NodeProgress"]	=	self.wndMain:FindChild("SlingerNode2:NodeProgress"),
		["SlingerNode3"]				=	self.wndMain:FindChild("SlingerNode3"),
		["SlingerNode3:NodeRed"]		=	self.wndMain:FindChild("SlingerNode3:NodeRed"),
		["SlingerNode3:NodeFlash"]		=	self.wndMain:FindChild("SlingerNode3:NodeFlash"),
		["SlingerNode3:NodeFilled"]		=	self.wndMain:FindChild("SlingerNode3:NodeFilled"),
		["SlingerNode3:NodeProgress"]	=	self.wndMain:FindChild("SlingerNode3:NodeProgress"),
		["SlingerNode4"]				=	self.wndMain:FindChild("SlingerNode4"),
		["SlingerNode4:NodeRed"]		=	self.wndMain:FindChild("SlingerNode4:NodeRed"),
		["SlingerNode4:NodeFlash"]		=	self.wndMain:FindChild("SlingerNode4:NodeFlash"),
		["SlingerNode4:NodeFilled"]		=	self.wndMain:FindChild("SlingerNode4:NodeFilled"),
		["SlingerNode4:NodeProgress"]	=	self.wndMain:FindChild("SlingerNode4:NodeProgress"),
		["ManaProgressBar"]				=	self.wndMain:FindChild("ManaProgressBar"),
		["ManaProgressText"]			=	self.wndMain:FindChild("ManaProgressText"),
		["ManaProgressBacker"]			=	self.wndMain:FindChild("ManaProgressBacker"),
	}

	self.tWindowMap["LargeSurgeGlow"]:Show(false, true)
	self.tWindowMap["LargeSurgeSigil"]:Show(false, true)
	self.tWindowMap["SlingerBaseFrame_InCombat"]:Show(false, true)
	self.tWindowMap["SlingerNode1:NodeProgress"]:SetProgress(250)
	self.tWindowMap["SlingerNode2:NodeProgress"]:SetProgress(250)
	self.tWindowMap["SlingerNode3:NodeProgress"]:SetProgress(250)
	self.tWindowMap["SlingerNode4:NodeProgress"]:SetProgress(250)

	self.bLastInCombat = nil
	self.nLastCurrent = nil
	self.nLastMax = nil
	self.bInnate = nil
	self.nLastMana = nil
	self.nFadeLevel = 0
	self.xmlDoc = nil

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self:OnSlingerEnteredCombat(unitPlayer, unitPlayer:IsInCombat())
	end
end

function ClassResources:OnSlingerUpdateTimer()
	local unitPlayer = GameLib.GetPlayerUnit()
	local bInCombat = unitPlayer:IsInCombat()
	local nManaCurrent = math.floor(unitPlayer:GetMana())
	local nResourceMax = unitPlayer:GetMaxResource(4)
	local nResourceCurrent = unitPlayer:GetResource(4)
	local bInnate = GameLib.IsSpellSurgeActive()
	if self.bLastInCombat == bInCombat and self.nLastCurrent == nResourceCurrent and self.nLastMax == nResourceMax and self.bInnate == bInnate and self.nLastMana == nManaCurrent then
		return
	end
	self.bLastInCombat = bInCombat
	self.nLastCurrent = nResourceCurrent
	self.nLastMax = nResourceMax
	self.bInnate = bInnate
	self.nLastMana = nManaCurrent

	-- Mana
	local nResourceMaxDiv4 = nResourceMax / 4
	local nManaMax = math.floor(unitPlayer:GetMaxMana())
	self.tWindowMap["ManaProgressBar"]:SetMax(nManaMax)
	self.tWindowMap["ManaProgressBar"]:SetProgress(nManaCurrent)
	self.tWindowMap["ManaProgressBar"]:SetTooltip(String_GetWeaselString(Apollo.GetString("SpellslingerResource_FocusTooltip"), nManaCurrent, nManaMax))
	self.tWindowMap["ManaProgressBar"]:SetStyleEx("EdgeGlow", bInCombat and (nManaCurrent / nManaMax < 0.97))
	self.tWindowMap["ManaProgressText"]:SetText(nManaCurrent == nManaMax and "" or (math.floor(nManaCurrent / nManaMax * 100).."%"))
	self.tWindowMap["ManaProgressText"]:SetTextColor(bInCombat and ApolloColor.new("ffffc757") or ApolloColor.new("UI_TextHoloTitle"))
	self.tWindowMap["ManaProgressBacker"]:Show(nManaCurrent ~= nManaMax)

	-- Nodes
	local strNodeTooltip = String_GetWeaselString(Apollo.GetString("Spellslinger_SpellSurge"), nResourceCurrent, nResourceMax)
	for idx = 1, 4 do
		local strNode = "SlingerNode"..idx
		local nPartialProgress = nResourceCurrent - (nResourceMaxDiv4 * (idx - 1)) -- e.g. 250, 500, 750, 1000
		local bThisBubbleFilled = nPartialProgress >= nResourceMaxDiv4
		self.tWindowMap[strNode..":NodeProgress"]:SetMax(nResourceMaxDiv4)
		self.tWindowMap[strNode..":NodeProgress"]:SetProgress(nPartialProgress, 100)

		if not bInCombat then
			self.tWindowMap[strNode..":NodeFilled"]:SetSprite("CM_SpellslingerSprites:sprSlinger_Node_"..idx.."Disabled")
			self.tWindowMap[strNode..":NodeProgress"]:SetFullSprite("CM_SpellslingerSprites:sprSlinger_NodeBar_OutOfCombat")
		elseif bThisBubbleFilled then
			self.tWindowMap[strNode..":NodeFilled"]:SetSprite("CM_SpellslingerSprites:sprSlinger_Node_"..idx.."Normal")
			self.tWindowMap[strNode..":NodeProgress"]:SetFullSprite("CM_SpellslingerSprites:sprSlinger_NodeBar_InCombatOrange")
		else
			self.tWindowMap[strNode..":NodeProgress"]:SetFullSprite("CM_SpellslingerSprites:sprSlinger_NodeBar_InCombatRed")
		end
		self.tWindowMap[strNode..":NodeFilled"]:Show(not bInCombat or bThisBubbleFilled, false, 0.2)
		self.tWindowMap[strNode..":NodeRed"]:Show(bInCombat and not bThisBubbleFilled, false, 0.2)

		-- Check last state
		local nLast = self.tWindowMap[strNode]:GetData() or nPartialProgress
		if bInCombat and nLast ~= nResourceMaxDiv4 and nPartialProgress == nResourceMaxDiv4 then -- Wasn't filled, now filled = just filled flash
			self.tWindowMap[strNode..":NodeFlash"]:SetSprite("CM_SpellslingerSprites:sprSlinger_NodeBar_Flash_Orange")
		end
		self.tWindowMap[strNode]:SetData(nPartialProgress)
		self.tWindowMap[strNode]:SetTooltip(strNodeTooltip)
	end

	-- Surge
	self.tWindowMap["LargeSurgeSigil"]:Show(bInnate, bInnate, 0.4)
	self.tWindowMap["LargeSurgeGlow"]:Show(bInnate and bInCombat, bInnate, 0.4)
	self.tWindowMap["SlingerBaseFrame_InCombat"]:SetSprite(nResourceCurrent < nResourceMaxDiv4 and "sprSlinger_Base_InCombatRed" or "sprSlinger_Base_InCombatOrange")
end

function ClassResources:OnSlingerEnteredCombat(unitPlayer, bInCombat)
	if unitPlayer ~= GameLib.GetPlayerUnit() or not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if bInCombat then
		self.tWindowMap["SlingerBaseFrame_InCombat"]:Show(true, false, 3)
		self.tWindowMap["LargeSurgeSigil"]:SetSprite("CM_SpellslingerSprites:sprSlinger_LargeSigil_InCombat")
		self.tWindowMap["ManaProgressBar"]:SetFullSprite("CM_SpellslingerSprites:sprSlinger_ManaBar_InCombat")
	else
		self.tWindowMap["SlingerBaseFrame_InCombat"]:Show(false, false, 3)
		self.tWindowMap["LargeSurgeSigil"]:SetSprite("CM_SpellslingerSprites:sprSlinger_LargeSigil_OutOfCombat")
		self.tWindowMap["ManaProgressBar"]:SetFullSprite("CM_SpellslingerSprites:sprSlinger_ManaBar_OutOfCombat")
	end
end

-----------------------------------------------------------------------------------------------
-- Medic
-----------------------------------------------------------------------------------------------

function ClassResources:OnCreateMedic()
	Apollo.RegisterEventHandler("VarChange_FrameCount", 		"OnMedicUpdateTimer", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 			"OnMedicEnteredCombat", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "MedicResourceForm", g_wndActionBarResources, self)
	self.wndMain:ToFront()

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop, true)

	self.tWindowMap =
	{
		["MedicBaseFrame_InCombat"]	=	self.wndMain:FindChild("MedicBaseFrame_InCombat"),
		["ManaProgressBacker"]		=	self.wndMain:FindChild("ManaProgressBacker"),
		["ManaProgressBar"]			=	self.wndMain:FindChild("ManaProgressBar"),
		["ManaProgressText"]		=	self.wndMain:FindChild("ManaProgressText"),
		["BG_7Squares"]				=	self.wndMain:FindChild("BG_7Squares"),
		["BG_12Squares"]			=	self.wndMain:FindChild("BG_12Squares"),
		["Bit_1"]					=	self.wndMain:FindChild("Bit_1"),
		["Bit_2"]					=	self.wndMain:FindChild("Bit_2"),
		["Bit_3"]					=	self.wndMain:FindChild("Bit_3"),
		["Bit_4"]					=	self.wndMain:FindChild("Bit_4"),
		["Bit_5"]					=	self.wndMain:FindChild("Bit_5"),
		["Bit_6"]					=	self.wndMain:FindChild("Bit_6"),
		["MedicNode1"]				=	self.wndMain:FindChild("MedicNode1"),
		["MedicNode2"]				=	self.wndMain:FindChild("MedicNode2"),
		["MedicNode3"]				=	self.wndMain:FindChild("MedicNode3"),
		["MedicNode4"]				=	self.wndMain:FindChild("MedicNode4"),
		["MedicNode1:FillSprite"]	=	self.wndMain:FindChild("MedicNode1:FillSprite"),
		["MedicNode2:FillSprite"]	=	self.wndMain:FindChild("MedicNode2:FillSprite"),
		["MedicNode3:FillSprite"]	=	self.wndMain:FindChild("MedicNode3:FillSprite"),
		["MedicNode4:FillSprite"]	=	self.wndMain:FindChild("MedicNode4:FillSprite"),
		["MedicNode1:EmptySprite"]	=	self.wndMain:FindChild("MedicNode1:EmptySprite"),
		["MedicNode2:EmptySprite"]	=	self.wndMain:FindChild("MedicNode2:EmptySprite"),
		["MedicNode3:EmptySprite"]	=	self.wndMain:FindChild("MedicNode3:EmptySprite"),
		["MedicNode4:EmptySprite"]	=	self.wndMain:FindChild("MedicNode4:EmptySprite"),
	}

	self.tWindowMap["MedicBaseFrame_InCombat"]:Show(false, true)
	self.bLastInCombat = nil
	self.nLastCurrent = nil
	self.nLastMax = nil
	self.bInnate = nil
	self.nLastPartialCount = nil
	self.bCombat = nil
	self.nLastMana = nil
	self.xmlDoc = nil

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self.bCombat = unitPlayer:IsInCombat()
		self:OnMedicEnteredCombat(unitPlayer, self.bCombat)
	end
end

function ClassResources:OnMedicUpdateTimer()
	local unitPlayer = GameLib.GetPlayerUnit()	-- Can instead just listen to a CharacterChange, CharacterCreate, etc. event
	local bInCombat = self.bCombat
	local nResourceMax = unitPlayer:GetMaxResource(1)
	local nResourceCurrent = unitPlayer:GetResource(1)
	local bInnate = GameLib.IsCurrentInnateAbilityActive()
	local nManaCurrent = math.floor(unitPlayer:GetMana())

	-- Partial Node Count
	local nPartialCount = 0
	local tBuffs = unitPlayer:GetBuffs()
	for idx, tCurrBuffData in pairs(tBuffs.arBeneficial or {}) do
		if tCurrBuffData.splEffect:GetId() == 42569 then -- TODO replace with code enum
			nPartialCount = tCurrBuffData.nCount
			break
		end
	end

	if self.bLastInCombat == bInCombat and self.nLastCurrent == nResourceCurrent and self.nLastMax == nResourceMax
		and self.bInnate == bInnate and self.nLastPartialCount == nPartialCount and self.nLastMana == nManaCurrent then
		return
	end
	self.bLastInCombat = bInCombat
	self.nLastCurrent = nResourceCurrent
	self.nLastMax = nResourceMax
	self.bInnate = bInnate
	self.nLastPartialCount = nPartialCount
	self.nLastMana = nManaCurrent

	-- Mana
	local nManaMax = math.floor(unitPlayer:GetMaxMana())
	self.tWindowMap["ManaProgressBar"]:SetMax(nManaMax)
	self.tWindowMap["ManaProgressBar"]:SetProgress(nManaCurrent)
	self.tWindowMap["ManaProgressBar"]:SetStyleEx("EdgeGlow", self.bCombat and (nManaCurrent / nManaMax < 0.97))
	self.tWindowMap["ManaProgressBar"]:SetTooltip(String_GetWeaselString(Apollo.GetString("MedicResource_FocusTooltip"), nManaCurrent, nManaMax))

	self.tWindowMap["ManaProgressText"]:SetText(nManaCurrent == nManaMax and "" or (math.floor(nManaCurrent / nManaMax * 100).."%"))
	self.tWindowMap["ManaProgressText"]:SetTextColor(self.bCombat and ApolloColor.new("UI_TextHoloTitle") or ApolloColor.new("ff56b381"))
	self.tWindowMap["ManaProgressBacker"]:Show(nManaCurrent ~= nManaMax)

	-- Nodes
	local bFirstPartial = true
	for idx = 1, 4 do
		-- Full vs Partial
		local strIndex = "MedicNode"..idx
		local bFull = nResourceCurrent >= idx
		local bShowPartial = bFirstPartial and nPartialCount > 0
		self.tWindowMap[strIndex..":FillSprite"]:Show(bFull or bShowPartial, not (bFull or bShowPartial))
		self.tWindowMap[strIndex..":EmptySprite"]:Show(not bFull)

		-- Anim
		local wndCurr = self.tWindowMap[strIndex]
		if bFull and not wndCurr:GetData() then
			wndCurr:SetSprite(self.bCombat and "sprMedic_Anim_BrightGreenGrow" or "sprMedic_Anim_OutOfCombatGreenGrow")
		elseif not bFull and wndCurr:GetData() then
			wndCurr:SetSprite(self.bCombat and "sprMedic_Anim_BrightGreenFade" or "sprMedic_Anim_OutOfCombatGreenFade")
		end
		wndCurr:SetData(bFull)

		-- Sprite
		local strSpriteToUse = ""
		if not self.bCombat then
			strSpriteToUse = "CM_MedicSprites:sprMedic_Cube_DullGreen"
		elseif bFull then
			strSpriteToUse = "CM_MedicSprites:sprMedic_Cube_BrightGreen_3"
		elseif not bFull and nPartialCount == 2 then
			strSpriteToUse = "CM_MedicSprites:sprMedic_Cube_BrightGreen_2"
			bFirstPartial = false
		elseif not bFull and nPartialCount == 1 then
			strSpriteToUse = "CM_MedicSprites:sprMedic_Cube_BrightGreen_1"
			bFirstPartial = false
		end
		self.tWindowMap[strIndex..":FillSprite"]:SetSprite(strSpriteToUse)
	end

	-- Innate
	if bInnate and not self.tWindowMap["BG_7Squares"]:GetData() then
		self.tWindowMap["BG_7Squares"]:SetSprite("sprMedic_Anim_7Squares")
		self.tWindowMap["Bit_1"]:SetSprite("sprMedic_Anim_Bit_1")
		self.tWindowMap["Bit_2"]:SetSprite("sprMedic_Anim_Bit_2")
		self.tWindowMap["Bit_3"]:SetSprite("sprMedic_Anim_Bit_3")
		self.tWindowMap["Bit_4"]:SetSprite("sprMedic_Anim_Bit_4")
		self.tWindowMap["Bit_5"]:SetSprite("sprMedic_Anim_Bit_5")
		self.tWindowMap["Bit_6"]:SetSprite("sprMedic_Anim_Bit_6")
	end
	self.tWindowMap["BG_7Squares"]:SetData(bInnate)
	self.tWindowMap["BG_12Squares"]:Show(bInnate)
	self.tWindowMap["MedicBaseFrame_InCombat"]:SetSprite(nResourceCurrent == 0 and "sprMedic_Base_InCombatRed" or "sprMedic_Base_InCombatGreen")
end

function ClassResources:OnMedicEnteredCombat(unitPlayer, bInCombat)
	if unitPlayer ~= GameLib.GetPlayerUnit() or not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.bCombat = bInCombat

	if bInCombat then
		self.tWindowMap["BG_12Squares"]:Show(true, false, 3)
		self.tWindowMap["MedicBaseFrame_InCombat"]:Show(true, false, 3)
		self.tWindowMap["ManaProgressBar"]:SetFullSprite("sprMedic_ProgBar_InCombat")
	else
		self.tWindowMap["BG_12Squares"]:Show(false, false, 3)
		self.tWindowMap["MedicBaseFrame_InCombat"]:Show(false, false, 3)
		self.tWindowMap["ManaProgressBar"]:SetFullSprite("sprMedic_ProgBar_OutOfCombat")
	end
end

-----------------------------------------------------------------------------------------------
-- Stalker
-----------------------------------------------------------------------------------------------

function ClassResources:OnCreateStalker()
	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnStalkerUpdateTimer", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "StalkerResourceForm", g_wndActionBarResources, self)
	self.wndMain:ToFront()

	local nLeft0, nTop0, nRight0, nBottom0 = self.wndMain:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop0 - 15, true)

	self.tWindowMap =
	{
		["Dot1"]				=	self.wndMain:FindChild("Dot1"),
		["Dot2"]				=	self.wndMain:FindChild("Dot2"),
		["Dot3"]				=	self.wndMain:FindChild("Dot3"),
		["CenterMeter1"]		=	self.wndMain:FindChild("CenterMeter1"),
		["CenterMeter2"]		=	self.wndMain:FindChild("CenterMeter2"),
		["CenterMeterText"]		=	self.wndMain:FindChild("CenterMeterText"),
		["Base"]				=	self.wndMain:FindChild("Base"),
		["Base:Full"]			=	self.wndMain:FindChild("Base:Full"),
		["Base:Innate"]			=	self.wndMain:FindChild("Base:Innate"),
		["Base:InCombat"]		=	self.wndMain:FindChild("Base:InCombat"),
		["Base:OutOfCombat"]	=	self.wndMain:FindChild("Base:OutOfCombat"),
		["Innate"]				=	self.wndMain:FindChild("Innate"),
		["Innate:InCombat"]		=	self.wndMain:FindChild("Innate:InCombat"),
		["Innate:OutOfCombat"]	=	self.wndMain:FindChild("Innate:OutOfCombat"),
	}

	self.bLastInCombat = nil
	self.nLastCurrent = nil
	self.nLastMax = nil
	self.bInnate = nil
	self.xmlDoc = nil
end

function ClassResources:OnStalkerUpdateTimer()
	local unitPlayer = GameLib.GetPlayerUnit()
	local bInCombat = unitPlayer:IsInCombat()
	local nResourceCurrent = unitPlayer:GetResource(3)
	local nResourceMax = unitPlayer:GetMaxResource(3)
	local bInnate = GameLib.IsCurrentInnateAbilityActive()
	if self.bLastInCombat == bInCombat and self.nLastCurrent == nResourceCurrent and self.nLastMax == nResourceMax and self.bInnate == bInnate then
		return
	end
	self.bLastInCombat = bInCombat
	self.nLastCurrent = nResourceCurrent
	self.nLastMax = nResourceMax
	self.bInnate = bInnate

	self.tWindowMap["CenterMeter1"]:SetStyleEx("EdgeGlow", nResourceCurrent < nResourceMax)
	self.tWindowMap["CenterMeter1"]:SetMax(nResourceMax)
	self.tWindowMap["CenterMeter1"]:SetProgress(nResourceCurrent)
	self.tWindowMap["CenterMeter2"]:SetStyleEx("EdgeGlow", nResourceCurrent < nResourceMax)
	self.tWindowMap["CenterMeter2"]:SetMax(nResourceMax)
	self.tWindowMap["CenterMeter2"]:SetProgress(nResourceCurrent)
	self.tWindowMap["CenterMeterText"]:SetText(nResourceCurrent)
	self.tWindowMap["CenterMeterText"]:Show(bInCombat or nResourceCurrent ~= nResourceMax)

	self.tWindowMap["Dot1"]:Show(not bInCombat and nResourceCurrent == nResourceMax)
	self.tWindowMap["Dot2"]:Show(not bInCombat and nResourceCurrent == nResourceMax)
	self.tWindowMap["Dot3"]:Show(bInCombat and nResourceCurrent == nResourceMax)

	-- Innate
	local strInnateWindow = ""
	if bInnate then
		strInnateWindow = bInCombat and "InCombat" or "OutOfCombat"
	end

	if self.tWindowMap["Innate"]:GetData() ~= strInnateWindow then
		self.tWindowMap["Innate"]:SetData(strInnateWindow)
		self.tWindowMap["Innate:InCombat"]:Show(false)
		self.tWindowMap["Innate:OutOfCombat"]:Show(false)
		if strInnateWindow ~= "" then
			self.tWindowMap["Innate:"..strInnateWindow]:Show(true)
		end
	end

	-- Base
	local strActiveWindow = "OutOfCombat"
	if bInCombat and nResourceCurrent == nResourceMax then
		strActiveWindow = "Full"
	elseif bInCombat then
		strActiveWindow = "Innate"
	end

	if self.tWindowMap["Base"]:GetData() ~= strActiveWindow then
		self.tWindowMap["Base"]:SetData(strActiveWindow)
		self.tWindowMap["Base:Full"]:Show(false)
		self.tWindowMap["Base:Innate"]:Show(false)
		self.tWindowMap["Base:InCombat"]:Show(false)
		self.tWindowMap["Base:OutOfCombat"]:Show(false)
		self.tWindowMap["Base:"..strActiveWindow]:Show(true, false, 0.3)

		self.tWindowMap["CenterMeterText"]:SetTextColor(bInCombat and ApolloColor.new("xkcdLightblue") or ApolloColor.new("UI_TextHoloTitle"))
		self.tWindowMap["CenterMeter1"]:Show(not bInCombat)
		self.tWindowMap["CenterMeter2"]:Show(bInCombat)
	end
end

-----------------------------------------------------------------------------------------------
-- Warrior
-----------------------------------------------------------------------------------------------

function ClassResources:OnCreateWarrior()
	self.timerOverdriveTick = ApolloTimer.Create(0.01, false, "OnWarriorResource_ChargeBarOverdriveTick", self)
	self.timerOverdriveTick:Stop()
	self.timerOverdriveDone = ApolloTimer.Create(10.0, false, "OnWarriorResource_ChargeBarOverdriveDone", self)
	self.timerOverdriveDone:Stop()

	Apollo.RegisterEventHandler("VarChange_FrameCount", 					"OnWarriorUpdateTimer", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "WarriorResourceForm", g_wndActionBarResources, self)
	self.wndMain:ToFront()

	local nLeft0, nTop0, nRight0, nBottom0 = self.wndMain:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop0 - 15, true)

	self.tWindowMap =
	{
		["Base"]					=	self.wndMain:FindChild("Base"),
		["BarBG"]					=	self.wndMain:FindChild("BarBG"),
		["Skulls"]					=	self.wndMain:FindChild("Skulls"),
		["Skulls:Skull0"]			=	self.wndMain:FindChild("Skulls:Skull0"),
		["Skulls:Skull1"]			=	self.wndMain:FindChild("Skulls:Skull1"),
		["Skulls:Skull2"]			=	self.wndMain:FindChild("Skulls:Skull2"),
		["Skulls:Skull3"]			=	self.wndMain:FindChild("Skulls:Skull3"),
		["Skulls:Skull4"]			=	self.wndMain:FindChild("Skulls:Skull4"),
		["ChargeBar"]				=	self.wndMain:FindChild("ChargeBar"),
		["ChargeBarOverdriven"]		=	self.wndMain:FindChild("ChargeBarOverdriven"),
		["InsetFrameDivider"]		=	self.wndMain:FindChild("InsetFrameDivider"),
		["ResourceCount"]			=	self.wndMain:FindChild("ResourceCount"),
	}

	for idx, wndCurr in pairs(self.tWindowMap["Skulls"]:GetChildren()) do
		wndCurr:Show(false, true)
	end

	self.tWindowMap["ChargeBarOverdriven"]:SetMax(1)

	self.bLastInCombat = nil
	self.nLastCurrent = nil
	self.nLastMax = nil
	self.bLastOverDrive = nil
	self.bOverDriveActive = false
	self.xmlDoc = nil
end

function ClassResources:OnWarriorUpdateTimer()
	local unitPlayer = GameLib.GetPlayerUnit()
	local bInCombat = unitPlayer:IsInCombat()
	local bOverdrive = GameLib.IsOverdriveActive()
	local nResourceCurr = unitPlayer:GetResource(1)
	local nResourceMax = unitPlayer:GetMaxResource(1)
	if self.bLastInCombat == bInCombat and self.nLastCurrent == nResourceCurr and self.nLastMax == nResourceMax and self.bLastOverdrive == bOverdrive then
		return
	end
	self.bLastInCombat = bInCombat
	self.nLastCurrent = nResourceCurr
	self.nLastMax = nResourceMax
	self.bLastOverdrive = bOverdrive

	self.tWindowMap["ChargeBar"]:SetMax(nResourceMax)
	self.tWindowMap["ChargeBar"]:SetProgress(nResourceCurr)

	if bOverdrive and not self.bOverDriveActive then
		self.bOverDriveActive = true
		self.tWindowMap["ChargeBarOverdriven"]:SetProgress(1)
		self.timerOverdriveTick:Start()
		self.timerOverdriveDone:Start()
	end

	self.tWindowMap["ChargeBar"]:Show(not bOverdrive)
	self.tWindowMap["ChargeBarOverdriven"]:Show(bOverdrive)
	self.tWindowMap["InsetFrameDivider"]:Show(not bOverdrive)
	self.tWindowMap["BarBG"]:SetSprite(bOverdrive and "spr_CM_Warrior_Innate" or "spr_CM_Warrior_Bar")

	local strBaseSprite = ""
	local strSplitSprite = ""
	local strSkullSprite = ""

	if bOverdrive then
		self.tWindowMap["BarBG"]:Show(true)
		self.tWindowMap["ResourceCount"]:SetText(Apollo.GetString("WarriorResource_OverdriveCaps"))
		self.tWindowMap["ResourceCount"]:SetTextColor(ApolloColor.new("xkcdAmber"))

		strSkullSprite = "Skull4"
		strBaseSprite = "spr_CM_Warrior_Base_Innate"
	else
		self.tWindowMap["BarBG"]:Show(nResourceCurr > 0 or bInCombat)
		self.tWindowMap["ResourceCount"]:SetText(nResourceCurr == 0 and "" or nResourceCurr)
		self.tWindowMap["ResourceCount"]:SetTextColor(ApolloColor.new("xkcdOrangeish"))
		self.tWindowMap["InsetFrameDivider"]:Show(nResourceCurr > 0 or bInCombat)

		strSkullSprite = bInCombat and "Skull"..math.min(3, math.floor(nResourceCurr / 250)) or ""
		strBaseSprite = bInCombat and "spr_CM_Warrior_Base_InCombat" or "spr_CM_Warrior_Base_OutOfCombatFade"
		strSplitSprite = nResourceMax > 1000 and "spr_CM_Warrior_Split4" or "spr_CM_Warrior_Split3"
	end

	if self.tWindowMap["Base"]:GetData() ~= strBaseSprite then
		self.tWindowMap["Base"]:SetSprite(strBaseSprite)
		self.tWindowMap["Base"]:SetData(strBaseSprite)
	end

	if self.tWindowMap["InsetFrameDivider"]:GetData() ~= strSplitSprite then
		self.tWindowMap["InsetFrameDivider"]:SetSprite(strSplitSprite)
		self.tWindowMap["InsetFrameDivider"]:SetData(strSplitSprite)
	end

	if self.tWindowMap["Skulls"]:GetData() ~= strSkullSprite then
		self.tWindowMap["Skulls"]:SetSprite(strSkullSprite)
		self.tWindowMap["Skulls"]:SetData(strSkullSprite)

		self.tWindowMap["Skulls:Skull0"]:Show(false, false, 0.05)
		self.tWindowMap["Skulls:Skull1"]:Show(false, false, 0.05)
		self.tWindowMap["Skulls:Skull2"]:Show(false, false, 0.05)
		self.tWindowMap["Skulls:Skull3"]:Show(false, false, 0.05)
		self.tWindowMap["Skulls:Skull4"]:Show(false, false, 0.05)
		if strSkullSprite ~= "" then
			self.tWindowMap["Skulls:"..strSkullSprite]:Show(true, false, 0.05)
		end
	end
end

function ClassResources:OnWarriorResource_ChargeBarOverdriveTick()
	self.timerOverdriveTick:Stop()
	self.tWindowMap["ChargeBarOverdriven"]:SetProgress(0, 1 / 8)
end

function ClassResources:OnWarriorResource_ChargeBarOverdriveDone()
	self.timerOverdriveDone:Stop()
	self.bOverDriveActive = false
end

-----------------------------------------------------------------------------------------------
-- Engineer
-----------------------------------------------------------------------------------------------

function ClassResources:OnCreateEngineer()
	Apollo.RegisterEventHandler("VarChange_FrameCount", 		"OnEngineerUpdateTimer", self)
	Apollo.RegisterEventHandler("ShowActionBarShortcut", 		"OnShowActionBarShortcut", self)
	Apollo.RegisterTimerHandler("EngineerOutOfCombatFade", 		"OnEngineerOutOfCombatFade", self)

	Apollo.RegisterEventHandler("PetStanceChanged", 			"OnPetStanceChanged", self)
	Apollo.RegisterEventHandler("PetSpawned",					"OnPetSpawned", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "EngineerResourceForm", g_wndActionBarResources, self)
	self.wndMain:ToFront()

	local nLeft0, nTop0, nRight0, nBottom0 = self.wndMain:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop0 - 15, true)

	self.tWindowMap =
	{
		["MainResourceFrame"]		=	self.wndMain:FindChild("MainResourceFrame"),
		["ProgressBar"]				=	self.wndMain:FindChild("ProgressBar"),
		["ProgressText"]			=	self.wndMain:FindChild("ProgressText"),
		["ProgressBacker"]			=	self.wndMain:FindChild("ProgressBacker"),
		["LeftCap"]					=	self.wndMain:FindChild("LeftCap"),
		["RightCap"]				=	self.wndMain:FindChild("RightCap"),
		["StanceMenuOpenerBtn"]		=	self.wndMain:FindChild("StanceMenuOpenerBtn"),
		["PetBarContainer"]			=	self.wndMain:FindChild("PetBarContainer"),
		["PetText"]					=	self.wndMain:FindChild("PetText"),
		["PetBtn"]					=	self.wndMain:FindChild("PetBtn"),
	}

	for idx = 1, 5 do
		self.wndMain:FindChild("Stance"..idx):SetData(idx)
	end
	
	self:HelperShowPetBar(self.bShowPet)
	self.wndMain:FindChild("StanceMenuOpenerBtn"):AttachWindow(self.wndMain:FindChild("StanceMenuBG"))

	self:OnShowActionBarShortcut(1, IsActionBarSetVisible(1)) -- Show petbar if active from reloadui/load screen

	-- Show initial Stance
	-- Pet_GetStance(0) -- First arg is for the pet ID, 0 means all engineer pets
	self.ktEngineerStanceToShortString =
	{
		[0] = "",
		[1] = Apollo.GetString("EngineerResource_Aggro"),
		[2] = Apollo.GetString("EngineerResource_Defend"),
		[3] = Apollo.GetString("EngineerResource_Passive"),
		[4] = Apollo.GetString("EngineerResource_Assist"),
		[5] = Apollo.GetString("EngineerResource_Stay"),
	}
	self.tWindowMap["PetText"]:SetText(self.ktEngineerStanceToShortString[Pet_GetStance(0)])
	self.tWindowMap["PetText"]:SetData(self.ktEngineerStanceToShortString[Pet_GetStance(0)])

	self.bLastInCombat = nil
	self.nLastCurrent = nil
	self.xmlDoc = nil
end

function ClassResources:OnEngineerUpdateTimer()
	local unitPlayer = GameLib.GetPlayerUnit()
	local bInCombat = unitPlayer:IsInCombat()
	local nResourceCurrent = unitPlayer:GetResource(1)
	
	if self.bLastInCombat == bInCombat and self.nLastCurrent == nResourceCurrent then
		return
	end
	
	self.bLastInCombat = bInCombat
	self.nLastCurrent = nResourceCurrent

	local nResourceMax = unitPlayer:GetMaxResource(1)
	local nResourcePercent = nResourceCurrent / nResourceMax

	self.tWindowMap["ProgressBar"]:SetMax(nResourceMax)
	self.tWindowMap["ProgressBar"]:SetProgress(nResourceCurrent)
	self.tWindowMap["ProgressText"]:SetText(String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nResourceCurrent, nResourceMax))
	self.tWindowMap["ProgressBacker"]:Show(nResourcePercent >= 0.4 and nResourcePercent <= 0.6)

	if nResourcePercent <= .05 then
		self.tWindowMap["ProgressBar"]:SetStyleEx("EdgeGlow", false)
		self.tWindowMap["LeftCap"]:Show(true)
		self.tWindowMap["RightCap"]:Show(false)
	elseif nResourcePercent > .05 and nResourcePercent < .95 then
		self.tWindowMap["ProgressBar"]:SetStyleEx("EdgeGlow", true)
		self.tWindowMap["LeftCap"]:Show(false)
		self.tWindowMap["RightCap"]:Show(false)
	elseif nResourcePercent >= .95 then
		self.tWindowMap["ProgressBar"]:SetStyleEx("EdgeGlow", false)
		self.tWindowMap["LeftCap"]:Show(false)
		self.tWindowMap["RightCap"]:Show(true)
	end

	if nResourcePercent > 0 and nResourcePercent < 0.3 then
		self.tWindowMap["ProgressText"]:SetTextColor("UI_TextHoloBodyHighlight")
		self.tWindowMap["ProgressBar"]:SetFullSprite("spr_CM_Engineer_BarFill_InCombat1")
		self.tWindowMap["ProgressBar"]:SetGlowSprite("spr_CM_Engineer_BarEdgeGlow_InCombat1")
	elseif nResourcePercent >= 0.3 and nResourcePercent <= 0.7 then
		self.tWindowMap["ProgressText"]:SetTextColor("ffffc757")
		self.tWindowMap["ProgressBar"]:SetFullSprite("spr_CM_Engineer_BarFill_InCombat2")
		self.tWindowMap["ProgressBar"]:SetGlowSprite("spr_CM_Engineer_BarEdgeGlow_InCombat2")
	elseif nResourcePercent > 0.7 then
		self.tWindowMap["ProgressText"]:SetTextColor("ffffeea4")
		self.tWindowMap["ProgressBar"]:SetFullSprite("spr_CM_Engineer_BarFill_InCombat2")
		self.tWindowMap["ProgressBar"]:SetGlowSprite("spr_CM_Engineer_BarEdgeGlow_InCombat3")
	else
		self.tWindowMap["ProgressText"]:SetTextColor("UI_AlphaPercent0")
		self.tWindowMap["ProgressBar"]:SetFullSprite("spr_CM_Engineer_BarFill_OutOfCombat")
		self.tWindowMap["ProgressBar"]:SetGlowSprite("spr_CM_Engineer_BarEdgeGlow_OutOfCombat")
	end

	if GameLib.IsCurrentInnateAbilityActive() then
		self.tWindowMap["ProgressBar"]:SetFullSprite("spr_CM_Engineer_BarFill_InCombat3")
		self.tWindowMap["MainResourceFrame"]:SetSprite("spr_CM_Engineer_Base_Innate")
	elseif bInCombat then
		self.tWindowMap["MainResourceFrame"]:SetSprite("spr_CM_Engineer_Base_InCombat")
	else
		self.tWindowMap["MainResourceFrame"]:SetSprite("spr_CM_Engineer_Base_OutOfCombat")
	end
end

function ClassResources:OnStanceBtn(wndHandler, wndControl)
	Pet_SetStance(0, tonumber(wndHandler:GetData())) -- First arg is for the pet ID, 0 means all engineer pets
	
	self.tWindowMap["StanceMenuOpenerBtn"]:SetCheck(false)
	self.tWindowMap["PetText"]:SetText(self.ktEngineerStanceToShortString[tonumber(wndHandler:GetData())])
	self.tWindowMap["PetText"]:SetData(self.ktEngineerStanceToShortString[tonumber(wndHandler:GetData())])
end

function ClassResources:HelperShowPetBar(bShowIt)
	self.tWindowMap["PetBarContainer"]:Show(bShowIt)
	self.tWindowMap["PetBtn"]:SetCheck(not bShowIt)
end

function ClassResources:OnPetBtn(wndHandler, wndControl)
	self.bShowPet = not self.tWindowMap["PetBarContainer"]:IsShown()
	
	self:HelperShowPetBar(self.bShowPet)
end

function ClassResources:OnShowActionBarShortcut(eWhichBar, bIsVisible, nNumShortcuts)
	if eWhichBar ~= ActionSetLib.CodeEnumShortcutSet.PrimaryPetBar or not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.tWindowMap["PetBtn"]:Show(bIsVisible)
	self.tWindowMap["PetBtn"]:SetCheck(not bIsVisible or not self.bShowPet)
	self.tWindowMap["PetBarContainer"]:Show(bIsVisible and self.bShowPet)
end

function ClassResources:OnEngineerPetBtnMouseEnter(wndHandler, wndControl)
	local strHover = ""
	local strWindowName = wndHandler:GetName()
	if strWindowName == "ActionBarShortcut.12" then
		strHover = Apollo.GetString("ClassResources_Engineer_PetAttack")
	elseif strWindowName == "ActionBarShortcut.13" then
		strHover = Apollo.GetString("CRB_Stop")
	elseif strWindowName == "ActionBarShortcut.15" then
		strHover = Apollo.GetString("ClassResources_Engineer_GoTo")
	end
	self.tWindowMap["PetText"]:SetText(strHover)
	wndHandler:SetBGColor("white")
end

function ClassResources:OnEngineerPetBtnMouseExit(wndHandler, wndControl)
	self.tWindowMap["PetText"]:SetText(self.tWindowMap["PetText"]:GetData() or "")
	wndHandler:SetBGColor("UI_AlphaPercent50")
end

function ClassResources:OnPetStanceChanged(petId)
	-- Pet_GetStance(0) -- First arg is for the pet ID, 0 means all engineer pets
	if self.ktEngineerStanceToShortString[Pet_GetStance(0)] then
		self.tWindowMap["PetText"]:SetText(self.ktEngineerStanceToShortString[Pet_GetStance(0)])
		self.tWindowMap["PetText"]:SetData(self.ktEngineerStanceToShortString[Pet_GetStance(0)])
	end
end

function ClassResources:OnPetSpawned(petId)
	-- Pet_GetStance(0) -- First arg is for the pet ID, 0 means all engineer pets
	if self.ktEngineerStanceToShortString[Pet_GetStance(0)] then
		self.tWindowMap["PetText"]:SetText(self.ktEngineerStanceToShortString[Pet_GetStance(0)])
		self.tWindowMap["PetText"]:SetData(self.ktEngineerStanceToShortString[Pet_GetStance(0)])
	end
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function ClassResources:OnGeneratePetCommandTooltip(wndControl, wndHandler, eType, arg1, arg2)
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_PetCommand then
		xml = XmlDoc.new()
		xml:AddLine(arg2)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Spell then
		xml = XmlDoc.new()
		if arg1 ~= nil then
			xml:AddLine(arg1:GetFlavor())
		end
		wndControl:SetTooltipDoc(xml)
	end
end

local ClassResourcesInst = ClassResources:new()
ClassResourcesInst:Init()
 BAnchorPoint="1" BAnchorOffset="-5" DT_VCENTER="1" DT_CENTER="1" BGColor="UI_BtnBGDefault" TextColor="UI_BtnTextDefault" NormalTextColor="UI_BtnTextDefault" PressedTextColor="UI_BtnTextDefault" FlybyTextColor="UI_BtnTextDefault" PressedFlybyTextColor="UI_BtnTextDefault" DisabledTextColor="UI_BtnTextDefault" TooltipType="OnCursor" Name="UndoBtn" TooltipColor="">
            <Event Name="ButtonSignal" Function="OnOptionUndo"/>
        </Control>
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="9" TAnchorPoint="0" TAnchorOffset="-2" RAnchorPoint="1" RAnchorOffset="-60" BAnchorPoint="1" BAnchorOffset="-2" RelativeToClient="1" Font="CRB_InterfaceSmall" Text="" BGColor="UI_WindowBGDefault" TextColor="UI_TextMetalGoldHighlight" Template="Default" TooltipType="OnCursor" Name="ListItemName" TooltipColor="" TextId="HairStyle" DT_VCENTER="1" DT_WORDBREAK="0"/>
        <Control Class="CashWindow" LAnchorPoint="1" LAnchorOffset="-103" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="-29" BAnchorPoint="1" BAnchorOffset="0" TooltipType="OnCursor" RelativeToClient="1" Font="CRB_Header9" Text="" Template="Default" BGColor="ffffffff" TextColor="UI_TextMetalBodyHighlight" DT_RIGHT="1" Name="CashWindow" TooltipColor="" SkipZeroes="1"/>
        <Pixie LAnchorPoint="0" LAnchorOffset="1" TAnchorPoint="1" TAnchorOffset="-1" RAnchorPoint="1" RAnchorOffset="-2" BAnchorPoint="1" BAnchorOffset="0" Sprite="WhiteFill" BGColor="UI_AlphaPercent5" TextColor="black" Rotation="0" Font="Default"/>
    </Form>
    <Form Class="Window" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="0" RAnchorOffset="280" BAnchorPoint="0" BAnchorOffset="34" RelativeToClient="1" Font="Default" Text="" BGColor="UI_WindowBGDefault" TextColor="UI_WindowTextDefault" Template="Default" TooltipType="OnCursor" Name="ConfirmationLineItem" Border="0" Picture="0" SwallowMouseClicks="1" Moveable="0" Escapable="1" Overlapped="1" TooltipColor="">
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="9" TAnchorPoint="0" TAnchorOffset="-2" RAnchorPoint="0" RAnchorOffset="162" BAnchorPoint="1" BAnchorOffset="-2" RelativeToClient="1" Font="CRB_InterfaceMedium" Text="" BGColor="UI_WindowBGDefault" TextColor="UI_TextHoloTitle" Template="Default" TooltipType="OnCursor" Name="ListItemName" TooltipColor="" TextId="CharacterCustomize_Bones" DT_VCENTER="1" DT_WORDBREAK="1"/>
        <Control Class="CashWindow" LAnchorPoint="0" LAnchorOffset="67" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="-5" BAnchorPoint="1" BAnchorOf