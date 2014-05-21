-----------------------------------------------------------------------------------------------
-- Client Lua Script for ClassResources
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local ClassResources = {}

local knEngineerPetGroupId = 298 -- TODO Hardcoded engineer pet grouping

local ktEngineerStanceToShortString =
{
	[0] = "",
	[1] = Apollo.GetString("EngineerResource_Aggro"),
	[2] = Apollo.GetString("EngineerResource_Defend"),
	[3] = Apollo.GetString("EngineerResource_Passive"),
	[4] = Apollo.GetString("EngineerResource_Assist"),
	[5] = Apollo.GetString("EngineerResource_Stay"),
}

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
		--self:OnCreateWarrior()
	end
end

-----------------------------------------------------------------------------------------------
-- Esper
-----------------------------------------------------------------------------------------------

function ClassResources:OnCreateEsper()
	Apollo.RegisterEventHandler("VarChange_FrameCount", 		"OnEsperUpdateTimer", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 			"OnEsperEnteredCombat", self)
	Apollo.RegisterTimerHandler("EsperOutOfCombatFade", 		"OnEsperOutOfCombatFade", self)
	Apollo.CreateTimer("EsperOutOfCombatFade", 0.5, false)
	Apollo.StopTimer("EsperOutOfCombatFade")

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "EsperResourceForm", g_wndActionBarResources, self)
	self.wndMain:FindChild("EsperBaseFrame_InCombat"):Show(false, true)
	self.wndMain:ToFront()

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop, true)

	self.nFadeLevel = 0
	self.xmlDoc = nil
end

function ClassResources:OnEsperUpdateTimer()
	local unitPlayer = GameLib.GetPlayerUnit()

	-- Mana
	local nManaMax = math.floor(unitPlayer:GetMaxMana())
	local nManaCurrent = math.floor(unitPlayer:GetMana())
	self.wndMain:FindChild("ManaProgressBar"):SetMax(nManaMax)
	self.wndMain:FindChild("ManaProgressBar"):SetProgress(nManaCurrent)
	self.wndMain:FindChild("ManaProgressBar"):SetTooltip(String_GetWeaselString(Apollo.GetString("EsperResource_FocusTooltip"), nManaCurrent, nManaMax))
	self.wndMain:FindChild("ManaProgressText"):SetText(nManaCurrent == nManaMax and "" or (math.floor(nManaCurrent / nManaMax * 100).."%"))

	-- Combo Points Animation
	local nComboMax = unitPlayer:GetMaxResource(1)
	local nComboCurrent = unitPlayer:GetResource(1)
	for idx = 5, 1, -1 do
		-- Death animation
		if nComboCurrent == 0 and self.wndMain:FindChild("ComboSolid"..idx):IsVisible() then
			--self.wndMain:FindChild("ComboGlowFlash"):SetSprite("CRB_Esper:sprEsperResource_CompFade"..idx)
			break
		end

		-- Birth Animation
		if nComboCurrent >= idx and not self.wndMain:FindChild("ComboSolid"..idx):IsVisible() then
			--self.wndMain:FindChild("ComboGlowFlash"):SetSprite("CRB_Esper:sprEsperResource_Glow"..idx)
			break
		end
	end

	-- Combo Points Solid
	local strInCombat = unitPlayer:IsInCombat() and "CM_EsperSprites:sprEsper_ComboNumPurple_" or "CM_EsperSprites:sprEsper_ComboNumDull_"
	self.wndMain:FindChild("ComboNumber"):SetSprite(strInCombat..nComboCurrent)
	self.wndMain:FindChild("ComboBits:ComboSolid1"):Show(nComboCurrent >= 1)
	self.wndMain:FindChild("ComboBits:ComboSolid2"):Show(nComboCurrent >= 2)
	self.wndMain:FindChild("ComboBits:ComboSolid3"):Show(nComboCurrent >= 3)
	self.wndMain:FindChild("ComboBits:ComboSolid4"):Show(nComboCurrent >= 4)
	self.wndMain:FindChild("ComboBits:ComboSolid5"):Show(nComboCurrent >= 5)

	-- Innate
	local bInnate = GameLib.IsCurrentInnateAbilityActive()
	if bInnate and not self.wndMain:FindChild("InnateActiveGlowTop"):GetData() then
		self.wndMain:FindChild("InnateActiveGlowTop"):SetData(true)
		self.wndMain:FindChild("InnateActiveGlowTop"):SetSprite("sprEsper_Anim_OuterGlow_Top")
		self.wndMain:FindChild("InnateActiveGlowBottom"):SetSprite("sprEsper_Anim_OuterGlow_Bottom")
		self.wndMain:FindChild("InnateActiveGlowFrame"):SetSprite("sprEsper_Anim_OuterGlow_Frame")
	elseif not bInnate then
		self.wndMain:FindChild("InnateActiveGlowTop"):SetData(false)
	end

	self:HelperToggleVisibiltyPreferences(self.wndMain, unitPlayer)
end

function ClassResources:OnEsperEnteredCombat(unitPlayer, bInCombat)
	if unitPlayer ~= GameLib.GetPlayerUnit() or not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if bInCombat then
		self.wndMain:FindChild("ManaProgressCover"):Show(true)
		self.wndMain:FindChild("EsperBaseFrame_InCombat"):Show(true)

		self.nFadeLevel = 0
		for idx, wndCurr in pairs(self.wndMain:FindChild("ComboBits"):GetChildren()) do
			wndCurr:SetBGColor(ApolloColor.new(1, 1, 1, 1))
		end

		Apollo.StopTimer("EsperOutOfCombatFade")
	else
		for idx, wndCurr in pairs(self.wndMain:FindChild("ComboBits"):GetChildren()) do
			wndCurr:SetBGColor(ApolloColor.new(1, 1, 1, 0.5))
		end

		self.wndMain:FindChild("ManaProgressCover"):Show(false)
		self.wndMain:FindChild("EsperBaseFrame_InCombat"):Show(false)
		Apollo.StartTimer("EsperOutOfCombatFade")
	end
end

function ClassResources:OnEsperOutOfCombatFade()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.nFadeLevel = self.nFadeLevel + 1
	for idx, wndCurr in pairs(self.wndMain:FindChild("ComboBits"):GetChildren()) do
		wndCurr:SetBGColor(ApolloColor.new(1, 1, 1, 0.5 - (0.025 * self.nFadeLevel)))
	end

	if self.nFadeLevel < 20 then
		Apollo.StartTimer("EsperOutOfCombatFade")
	end
end

-----------------------------------------------------------------------------------------------
-- Spellslinger
-----------------------------------------------------------------------------------------------

function ClassResources:OnCreateSlinger()
	Apollo.RegisterEventHandler("VarChange_FrameCount", 		"OnSlingerUpdateTimer", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 			"OnSlingerEnteredCombat", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "SlingerResourceForm", g_wndActionBarResources, self)
	self.wndMain:FindChild("LargeSurgeGlow"):Show(false, true)
	self.wndMain:FindChild("LargeSurgeSigil"):Show(false, true)
	self.wndMain:FindChild("SlingerBaseFrame_InCombat"):Show(false, true)
	self.wndMain:ToFront()

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop, true)

	self.wndSlinger1 = self.wndMain:FindChild("SlingerNode1")
	self.wndSlinger2 = self.wndMain:FindChild("SlingerNode2")
	self.wndSlinger3 = self.wndMain:FindChild("SlingerNode3")
	self.wndSlinger4 = self.wndMain:FindChild("SlingerNode4")
	self.wndSlinger1:FindChild("NodeProgress"):SetProgress(250)
	self.wndSlinger2:FindChild("NodeProgress"):SetProgress(250)
	self.wndSlinger3:FindChild("NodeProgress"):SetProgress(250)
	self.wndSlinger4:FindChild("NodeProgress"):SetProgress(250)

	self.nFadeLevel = 0
	self.xmlDoc = nil

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self:OnSlingerEnteredCombat(unitPlayer, unitPlayer:IsInCombat())
	end
end

function ClassResources:OnSlingerUpdateTimer()
	local unitPlayer = GameLib.GetPlayerUnit()
	local nResourceMax = unitPlayer:GetMaxResource(4)
	local nResourceCurrent = unitPlayer:GetResource(4)
	local nResourceMaxDiv4 = nResourceMax / 4
	local bSurgeActive = GameLib.IsSpellSurgeActive()
	local bInCombat = unitPlayer:IsInCombat()

	-- Mana
	local nManaMax = math.floor(unitPlayer:GetMaxMana())
	local nManaCurrent = math.floor(unitPlayer:GetMana())
	self.wndMain:FindChild("ManaProgressBar"):SetMax(nManaMax)
	self.wndMain:FindChild("ManaProgressBar"):SetProgress(nManaCurrent)
	self.wndMain:FindChild("ManaProgressBar"):SetTooltip(String_GetWeaselString(Apollo.GetString("SpellslingerResource_FocusTooltip"), nManaCurrent, nManaMax))
	self.wndMain:FindChild("ManaProgressBar"):SetStyleEx("EdgeGlow", bInCombat and (nManaCurrent / nManaMax < 0.97))
	self.wndMain:FindChild("ManaProgressText"):SetText(nManaCurrent == nManaMax and "" or (math.floor(nManaCurrent / nManaMax * 100).."%"))
	self.wndMain:FindChild("ManaProgressText"):SetTextColor(bInCombat and ApolloColor.new("ffffc757") or ApolloColor.new("UI_TextHoloTitle"))
	self.wndMain:FindChild("ManaProgressBacker"):Show(nManaCurrent ~= nManaMax)

	-- Nodes
	local strNodeTooltip = String_GetWeaselString(Apollo.GetString("Spellslinger_SpellSurge"), nResourceCurrent, nResourceMax)
	for idx, wndCurr in pairs({ self.wndSlinger1, self.wndSlinger2, self.wndSlinger3, self.wndSlinger4 }) do
		local nPartialProgress = nResourceCurrent - (nResourceMaxDiv4 * (idx - 1)) -- e.g. 250, 500, 750, 1000
		local bThisBubbleFilled = nPartialProgress >= nResourceMaxDiv4
		wndCurr:FindChild("NodeProgress"):SetMax(nResourceMaxDiv4)
		wndCurr:FindChild("NodeProgress"):SetProgress(nPartialProgress, 100)

		if not bInCombat then
			wndCurr:FindChild("NodeFilled"):SetSprite("CM_SpellslingerSprites:sprSlinger_Node_"..idx.."Disabled")
			wndCurr:FindChild("NodeProgress"):SetFullSprite("CM_SpellslingerSprites:sprSlinger_NodeBar_OutOfCombat")
		elseif bThisBubbleFilled then
			wndCurr:FindChild("NodeFilled"):SetSprite("CM_SpellslingerSprites:sprSlinger_Node_"..idx.."Normal")
			wndCurr:FindChild("NodeProgress"):SetFullSprite("CM_SpellslingerSprites:sprSlinger_NodeBar_InCombatOrange")
		else
			wndCurr:FindChild("NodeProgress"):SetFullSprite("CM_SpellslingerSprites:sprSlinger_NodeBar_InCombatRed")
		end
		wndCurr:FindChild("NodeFilled"):Show(not bInCombat or bThisBubbleFilled, false, 0.2)
		wndCurr:FindChild("NodeRed"):Show(bInCombat and not bThisBubbleFilled, false, 0.2)

		-- Check last state
		local nLast = wndCurr:GetData() or nPartialProgress
		if bInCombat and nLast ~= nResourceMaxDiv4 and nPartialProgress == nResourceMaxDiv4 then -- Wasn't filled, now filled = just filled flash
			wndCurr:FindChild("NodeFlash"):SetSprite("CM_SpellslingerSprites:sprSlinger_NodeBar_Flash_Orange")
		end
		wndCurr:SetData(nPartialProgress)
		wndCurr:SetTooltip(strNodeTooltip)
	end

	-- Surge
	self.wndMain:FindChild("LargeSurgeSigil"):Show(bSurgeActive, bSurgeActive, 0.4)
	self.wndMain:FindChild("LargeSurgeGlow"):Show(bSurgeActive and bInCombat, bSurgeActive, 0.4)

	self.wndMain:FindChild("SlingerBaseFrame_InCombat"):SetSprite(nResourceCurrent < nResourceMaxDiv4 and "sprSlinger_Base_InCombatRed" or "sprSlinger_Base_InCombatOrange")

	self:HelperToggleVisibiltyPreferences(self.wndMain, unitPlayer)
end

function ClassResources:OnSlingerEnteredCombat(unitPlayer, bInCombat)
	if unitPlayer ~= GameLib.GetPlayerUnit() or not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if bInCombat then
		self.wndMain:FindChild("SlingerBaseFrame_InCombat"):Show(true, false, 3)
		self.wndMain:FindChild("LargeSurgeSigil"):SetSprite("CM_SpellslingerSprites:sprSlinger_LargeSigil_InCombat")
		self.wndMain:FindChild("ManaProgressBar"):SetFullSprite("CM_SpellslingerSprites:sprSlinger_ManaBar_InCombat")
	else
		self.wndMain:FindChild("SlingerBaseFrame_InCombat"):Show(false, false, 3)
		self.wndMain:FindChild("LargeSurgeSigil"):SetSprite("CM_SpellslingerSprites:sprSlinger_LargeSigil_OutOfCombat")
		self.wndMain:FindChild("ManaProgressBar"):SetFullSprite("CM_SpellslingerSprites:sprSlinger_ManaBar_OutOfCombat")
	end
end

-----------------------------------------------------------------------------------------------
-- Medic
-----------------------------------------------------------------------------------------------

function ClassResources:OnCreateMedic()
	Apollo.RegisterEventHandler("VarChange_FrameCount", 		"OnMedicUpdateTimer", self)
	Apollo.RegisterEventHandler("UnitEnteredCombat", 			"OnMedicEnteredCombat", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "MedicResourceForm", g_wndActionBarResources, self)
	self.wndMain:FindChild("MedicBaseFrame_InCombat"):Show(false, true)
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

	self.xmlDoc = nil
	self.bCombat = nil

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self.bCombat = unitPlayer:IsInCombat()
		self:OnMedicEnteredCombat(unitPlayer, self.bCombat)
	end
end

function ClassResources:OnMedicUpdateTimer()
	local unitPlayer = GameLib.GetPlayerUnit()	-- Can instead just listen to a CharacterChange, CharacterCreate, etc. event
	local nResourceMax = unitPlayer:GetMaxResource(1)
	local nResourceCurrent = unitPlayer:GetResource(1)
	local tBuffs = unitPlayer:GetBuffs()

	-- Mana
	local nManaMax = math.floor(unitPlayer:GetMaxMana())
	local nManaCurrent = math.floor(unitPlayer:GetMana())
	self.tWindowMap["ManaProgressBar"]:SetMax(nManaMax)
	self.tWindowMap["ManaProgressBar"]:SetProgress(nManaCurrent)
	self.tWindowMap["ManaProgressBar"]:SetStyleEx("EdgeGlow", self.bCombat and (nManaCurrent / nManaMax < 0.97))
	self.tWindowMap["ManaProgressBar"]:SetTooltip(String_GetWeaselString(Apollo.GetString("MedicResource_FocusTooltip"), nManaCurrent, nManaMax))

	self.tWindowMap["ManaProgressText"]:SetText(nManaCurrent == nManaMax and "" or (math.floor(nManaCurrent / nManaMax * 100).."%"))
	self.tWindowMap["ManaProgressText"]:SetTextColor(self.bCombat and ApolloColor.new("UI_TextHoloTitle") or ApolloColor.new("ff56b381"))
	self.tWindowMap["ManaProgressBacker"]:Show(nManaCurrent ~= nManaMax)

	-- Partial Node Count
	local nPartialCount = 0
	for idx, tCurrBuffData in pairs(tBuffs.arBeneficial or {}) do
		if tCurrBuffData.splEffect:GetId() == 42569 then -- TODO replace with code enum
			nPartialCount = tCurrBuffData.nCount
			break
		end
	end

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
	local bInnate = GameLib.IsCurrentInnateAbilityActive()
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

	self:HelperToggleVisibiltyPreferences(self.wndMain, unitPlayer)
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
-- Engineer
-----------------------------------------------------------------------------------------------

function ClassResources:OnCreateEngineer()
	Apollo.RegisterEventHandler("VarChange_FrameCount", 		"OnEngineerUpdateTimer", self)
	Apollo.RegisterEventHandler("ShowActionBarShortcut", 		"OnShowActionBarShortcut", self)
	Apollo.RegisterTimerHandler("EngineerOutOfCombatFade", 		"OnEngineerOutOfCombatFade", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "EngineerResourceForm", g_wndActionBarResources, self)
	self.wndMain:FindChild("StanceMenuOpenerBtn"):AttachWindow(self.wndMain:FindChild("StanceMenuBG"))

	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop, true)

	for idx = 1, 5 do
		self.wndMain:FindChild("Stance"..idx):SetData(idx)
	end

	self:OnShowActionBarShortcut(1, IsActionBarSetVisible(1)) -- Show petbar if active from reloadui/load screen

	self.xmlDoc = nil
end

function ClassResources:OnEngineerUpdateTimer()
	if not self.wndMain then
		return
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	local bInCombat = unitPlayer:IsInCombat()
	local nResourceMax = unitPlayer:GetMaxResource(1)
	local nResourceCurrent = unitPlayer:GetResource(1)
	local nResourcePercent = nResourceCurrent / nResourceMax

	local wndMainResourceFrame = self.wndMain:FindChild("MainResourceFrame")
	local wndProgressFrame = wndMainResourceFrame:FindChild("BaseProgressFrame")
	if not wndMainResourceFrame or not wndProgressFrame then
		return
	end

	local wndBar = wndProgressFrame:FindChild("ProgressBar")
	local wndBarText = wndProgressFrame:FindChild("ProgressText")
	wndBar:SetMax(nResourceMax)
	wndBar:SetProgress(nResourceCurrent)
	wndBarText:SetText(String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), nResourceCurrent, nResourceMax))

	local wndLeftCap = wndProgressFrame:FindChild("LeftCap")
	local wndRightCap = wndProgressFrame:FindChild("RightCap")

	if nResourcePercent <= .05 then
		wndBar:SetStyleEx("EdgeGlow", false)
		wndLeftCap:Show(true)
		wndRightCap:Show(false)
	elseif nResourcePercent > .05 and nResourcePercent < .95 then
		wndBar:SetStyleEx("EdgeGlow", true)
		wndLeftCap:Show(false)
		wndRightCap:Show(false)
	elseif nResourcePercent >= .95 then
		wndBar:SetStyleEx("EdgeGlow", false)
		wndLeftCap:Show(false)
		wndRightCap:Show(true)
	end

	wndProgressFrame:FindChild("ProgressBacker"):Show(nResourcePercent >= 0.4 and nResourcePercent <= 0.6)
	if nResourcePercent > 0 and nResourcePercent < 0.3 then
		wndBarText:SetTextColor("UI_TextHoloBodyHighlight")
		wndBar:SetFullSprite("spr_CM_Engineer_BarFill_InCombat1")
		wndBar:SetGlowSprite("spr_CM_Engineer_BarEdgeGlow_InCombat1")
	elseif nResourcePercent >= 0.3 and nResourcePercent <= 0.7 then
		wndBarText:SetTextColor("ffffc757")
		wndBar:SetFullSprite("spr_CM_Engineer_BarFill_InCombat2")
		wndBar:SetGlowSprite("spr_CM_Engineer_BarEdgeGlow_InCombat2")
	elseif nResourcePercent > 0.7 then
		wndBarText:SetTextColor("ffffeea4")
		wndBar:SetFullSprite("spr_CM_Engineer_BarFill_InCombat2")
		wndBar:SetGlowSprite("spr_CM_Engineer_BarEdgeGlow_InCombat3")
	else
		wndBarText:SetTextColor("UI_AlphaPercent0")
		wndBar:SetFullSprite("spr_CM_Engineer_BarFill_OutOfCombat")
		wndBar:SetGlowSprite("spr_CM_Engineer_BarEdgeGlow_OutOfCombat")
	end

	if GameLib.IsCurrentInnateAbilityActive() then
		wndBar:SetFullSprite("spr_CM_Engineer_BarFill_InCombat3")
		wndMainResourceFrame:SetSprite("spr_CM_Engineer_Base_Innate")
	elseif bInCombat then
		wndMainResourceFrame:SetSprite("spr_CM_Engineer_Base_InCombat")
	else
		wndMainResourceFrame:SetSprite("spr_CM_Engineer_Base_OutOfCombat")
	end

	self:HelperToggleVisibiltyPreferences(self.wndMain, unitPlayer)
end

function ClassResources:OnStanceBtn(wndHandler, wndControl)
	Pet_SetStance(0, tonumber(wndHandler:GetData())) -- First arg is for the pet ID, 0 means all engineer pets
	self.wndMain:FindChild("StanceMenuOpenerBtn"):SetCheck(false)
	self.wndMain:FindChild("PetText"):SetText(wndHandler:GetText())
	self.wndMain:FindChild("PetText"):SetData(wndHandler:GetText())
end

function ClassResources:OnPetBtn(wndHandler, wndControl)
	 local wndPetContainer = self.wndMain:FindChild("PetBarContainer")
	 wndPetContainer:Show(not wndPetContainer:IsShown())
end

function ClassResources:OnShowActionBarShortcut(nWhichBar, bIsVisible, nNumShortcuts)
	if nWhichBar ~= 1 or not self.wndMain or not self.wndMain:IsValid() then -- 1 is hardcoded to be the engineer pet bar
		return
	end

	self.wndMain:FindChild("PetBtn"):Show(bIsVisible)
	self.wndMain:FindChild("PetBarContainer"):Show(bIsVisible)
end

function ClassResources:OnEngineerPetBtnMouseEnter(wndHandler, wndControl)
	wndHandler:SetBGColor("white")
	local strHover = ""
	local strWindowName = wndHandler:GetName()
	if strWindowName == "ActionBarShortcut.12" then
		strHover = Apollo.GetString("ClassResources_Engineer_PetAttack")
	elseif strWindowName == "ActionBarShortcut.13" then
		strHover = Apollo.GetString("CRB_Stop")
	elseif strWindowName == "ActionBarShortcut.15" then
		strHover = Apollo.GetString("ClassResources_Engineer_GoTo")
	end
	self.wndMain:FindChild("PetText"):SetText(strHover)
end

function ClassResources:OnEngineerPetBtnMouseExit(wndHandler, wndControl)
	wndHandler:SetBGColor("UI_AlphaPercent50")
	self.wndMain:FindChild("PetText"):SetText(self.wndMain:FindChild("PetText"):GetData() or "")
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function ClassResources:HelperToggleVisibiltyPreferences(wndParent, unitPlayer)
	-- TODO: REFACTOR: Only need to update this on Combat Enter/Exit
	--Toggle Visibility based on ui preference
	local nVisibility = Apollo.GetConsoleVariable("hud.ResourceBarDisplay")

	if nVisibility == 2 then --always off
		wndParent:Show(false)
	elseif nVisibility == 3 then --on in combat
		wndParent:Show(unitPlayer:IsInCombat())
	elseif nVisibility == 4 then --on out of combat
		wndParent:Show(not unitPlayer:IsInCombat())
	else
		wndParent:Show(true)
	end
end

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
