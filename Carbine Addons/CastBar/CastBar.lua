-----------------------------------------------------------------------------------------------
-- Client Lua Script for CastBar
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Sound"
require "GameLib"
require "Spell"

local CastBar 				= {}
local kstrOpSpellCircleFont = "CRB_HeaderLarge_O"
local kcrOpSpellCurrent 	= "ffffffff"
local kcrOpSpellMax 		= "ffa0a0a0"
local knMaxTiers 			= 5 --max tiers a charge-up spell can have

function CastBar:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	self.bIsShown = false
	return o
end

function CastBar:Init()
	Apollo.RegisterAddon(self)
end

function CastBar:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("CastBar.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function CastBar:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end

	-- Spell Threshold events
	Apollo.RegisterEventHandler("StartSpellThreshold", 	"OnStartSpellThreshold", self)
	Apollo.RegisterEventHandler("ClearSpellThreshold", 	"OnClearSpellThreshold", self)
	Apollo.RegisterEventHandler("UpdateSpellThreshold", "OnUpdateSpellThreshold", self)
	
	self.wndCastFrame 		= Apollo.LoadForm(self.xmlDoc, "CastBarFrame", "InWorldHudStratum", self)
	self.wndOppFrame 		= Apollo.LoadForm(self.xmlDoc, "WindowOfOppFrame", "InWorldHudStratum", self)
	self.wndOppBar 			= self.wndOppFrame:FindChild("SingleBar")
	self.wndOppBarCircle 	= self.wndOppFrame:FindChild("CircleBar")
	self.wndOppBarTiered 	= self.wndOppFrame:FindChild("SingleBarTiered")
	
	self.wndOppFrame:FindChild("Fill"):SetMax(1)
	self.tCurrentOpSpell = nil

	self.arTierSprites 	= {}
	self.tTierMarks 	= {}
	for idx = 1, knMaxTiers do
		local tSprites = 
		{
			strFillSprite 	= "CRB_CastBarSprites:sprCB_Fill_PHR_" .. idx,
			strCapSprite 	= "CRB_CastBarSprites:sprCB_Cap_PHR_" .. idx,
			strMarkEmpty 	= "CRB_CastBarSprites:sprCB_PHRMarkerEmpty_" .. idx,
			strMarkFull 	= "CRB_CastBarSprites:sprCB_PHRMarkerFull_" .. idx,
		}
		table.insert(self.arTierSprites, idx, tSprites)

		local wndTierItem = Apollo.LoadForm(self.xmlDoc, "TierItem", self.wndOppBarTiered:FindChild("TierMarkContainer"), self)
		
		wndTierItem:Show(false)
		table.insert(self.tTierMarks, idx, wndTierItem)
	end
	self.xmlDoc = nil
	self.nCastLeft, self.nCastTop, self.nCastRight, self.nCastBottom = self.wndCastFrame:GetAnchorOffsets()
	self.nOppLeft, self.nOppTop, self.nOppRight, self.nOppBottom = self.wndOppFrame:GetAnchorOffsets()
	
	self.wndCastFrame:Show(false, true)
	self.wndOppFrame:Show(false, true)
	
	self.timerUpdateCastBar = ApolloTimer.Create(0.033, true, "OnUpdate", self)
end

function CastBar:OnUpdate()
	local unitPlayer = GameLib.GetPlayerUnit()
	local nRectLeft, nRectTop, nRectRight, nRectBottom = self.wndCastFrame:GetRect()

	if not unitPlayer then
		return
	end

	if self.tCurrentOpSpell ~= nil then
		if self.tCurrentOpSpell.eCastMethod == Spell.CodeEnumCastMethod.RapidTap then
			self:DrawSingleBarFrameCircle(self.wndOppBarCircle)
		elseif self.tCurrentOpSpell.eCastMethod == Spell.CodeEnumCastMethod.PressHold then
			self:DrawSingleBarFrame(self.wndOppBar)
		elseif self.tCurrentOpSpell.eCastMethod == Spell.CodeEnumCastMethod.ChargeRelease then
			self:DrawSingleBarFrameTiered(self.wndOppBarTiered)
		end
	end
	
	local bShowSimpleCast = true
	--Toggle Visibility based on ui preference (Hide simple cast bar if my unit frame is visible.)
	local unitPlayer = GameLib.GetPlayerUnit()
	local nVisibility = Apollo.GetConsoleVariable("hud.myUnitFrameDisplay")
	
	if nVisibility == 1 or nVisibility == 0  then --always on/unspecified
		bShowSimpleCast = false
	elseif nVisibility == 2 then --always off
		bShowSimpleCast = true
	elseif nVisibility == 3 then --on in combat
		bShowSimpleCast = not unitPlayer:IsInCombat()
	elseif nVisibility == 4 then --on out of combat
		bShowSimpleCast = unitPlayer:IsInCombat()
	end
	
	-- Casting Bar Update
	local bShowCasting = false
	local bEnableGlow = false
	local nZone = 0
	local nMaxZone = 0
	local fDuration = 0
	local fElapsed = 0
	local strSpellName = ""
	local nElapsed = 0
	local eType = Unit.CodeEnumCastBarType.None

	if unitPlayer:ShouldShowCastBar() then
		if bShowSimpleCast then
			self.bIsShown = true
			eType = unitPlayer:GetCastBarType()
			
			if eType == Unit.CodeEnumCastBarType.Normal then
				self.wndCastFrame:FindChild("CastingProgress"):SetFullSprite("SpellChargeFull")

				bShowCasting = true
				bEnableGlow = true
				nZone = 0
				nMaxZone = 1
				fDuration = unitPlayer:GetCastDuration()
				fElapsed = unitPlayer:GetCastElapsed()

				self.wndCastFrame:FindChild("CastingProgress"):SetTickLocations(0, 100, 200, 300)

				strSpellName = unitPlayer:GetCastName()
			end
			
			Apollo.SetGlobalAnchor("CenterTextBottom", 0.0, nRectTop, true)
		end
	else
		self.bIsShown = false
		self.wndCastFrame:Show(false)
		Apollo.SetGlobalAnchor("CenterTextBottom", 0.0, nRectBottom, true)
	end

	if bShowCasting and fDuration > 0 and nMaxZone > 0 then
		self.wndCastFrame:Show(bShowCasting)

		self.wndCastFrame:FindChild("CastingProgress"):SetMax(fDuration)
		self.wndCastFrame:FindChild("CastingProgress"):SetProgress(fElapsed)
		self.wndCastFrame:FindChild("CastingProgress"):EnableGlow(bEnableGlow)
		self.wndCastFrame:FindChild("CastingProgressText"):SetText(strSpellName)
	end

	-- reposition if needed
	if self.wndCastFrame:IsShown() and self.wndOppFrame:IsShown() then
		local nLeft, nTop, nRight, nBottom = self.wndOppFrame:GetAnchorOffsets()
		if nBottom ~= self.nCastTop then
			self.wndOppFrame:SetAnchorOffsets(self.nOppLeft, self.nOppTop + self.nCastTop, self.nOppRight, self.nOppBottom + self.nCastTop)
		end
	elseif self.wndOppFrame:IsShown() then
		local nLeft,nTop,nRight,nBottom = self.wndOppFrame:GetAnchorOffsets()
		if nBottom ~= self.nOppBottom then
			self.wndOppFrame:SetAnchorOffsets(self.nOppLeft, self.nOppTop, self.nOppRight, self.nOppBottom)
		end
	end
end

function CastBar:DrawSingleBarFrame(wnd)
	local fPercentDone = GameLib.GetSpellThresholdTimePrcntDone(self.tCurrentOpSpell.id)
	wnd:FindChild("Fill"):SetMax(1)	
	wnd:FindChild("Fill"):SetProgress(fPercentDone)
	
	local strExtra = Apollo.GetString("CastBar_Press")
	if Apollo.GetConsoleVariable("spell.useButtonDownForAbilities") then
		strExtra = Apollo.GetString("CastBar_Hold")
	end
	
	wnd:FindChild("Label"):SetText(String_GetWeaselString(Apollo.GetString("CastBar_ComplexLabel"), self.tCurrentOpSpell.strName, strExtra))
end

function CastBar:DrawSingleBarFrameCircle(wnd)
	local fPercentDone = GameLib.GetSpellThresholdTimePrcntDone(self.tCurrentOpSpell.id)
	wnd:FindChild("Fill"):SetMax(1)
	wnd:FindChild("Fill"):SetProgress(1 - fPercentDone)
	local strTier = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrOpSpellCircleFont, kcrOpSpellCurrent, self.tCurrentOpSpell.nCurrentTier)
	local strMax = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", kstrOpSpellCircleFont, kcrOpSpellMax, self.tCurrentOpSpell.nMaxTier)
	wnd:FindChild("Label"):SetText(string.format("<P Font=\"%s\" Align=\"Center\">%s/%s</P>", kstrOpSpellCircleFont, strTier, strMax))
	wnd:FindChild("NameLabel"):SetText(self.tCurrentOpSpell.strName)
end

function CastBar:DrawSingleBarFrameTiered(wnd)
	local fPercentDone = GameLib.GetSpellThresholdTimePrcntDone(self.tCurrentOpSpell.id)
	wnd:FindChild("Fill"):SetFillSprite(self.arTierSprites[self.tCurrentOpSpell.nCurrentTier].strFillSprite)
	wnd:FindChild("Fill"):SetGlowSprite(self.arTierSprites[self.tCurrentOpSpell.nCurrentTier].strCapSprite)

	if self.tCurrentOpSpell.nCurrentTier > 1 then
		wnd:FindChild("FillBacker"):SetSprite(self.arTierSprites[self.tCurrentOpSpell.nCurrentTier - 1].strFillSprite)
	else
		wnd:FindChild("FillBacker"):SetSprite("")
	end

	wnd:FindChild("Fill"):SetMax(1)

	if self.tCurrentOpSpell.nCurrentTier == self.tCurrentOpSpell.nMaxTier then
		wnd:FindChild("Fill"):SetProgress(.99) -- last tier would read as empty; this fixes it
		wnd:FindChild("Fill"):SetGlowSprite("")
	else
		wnd:FindChild("Fill"):SetProgress(fPercentDone)
	end
	
	local strExtra = Apollo.GetString("CastBar_Press")
	if Apollo.GetConsoleVariable("spell.useButtonDownForAbilities") then
		strExtra = Apollo.GetString("CastBar_Hold")
	end

	wnd:FindChild("AlertFlash"):Show(self.tCurrentOpSpell.nCurrentTier == self.tCurrentOpSpell.nMaxTier)
	wnd:FindChild("Label"):SetText(String_GetWeaselString(Apollo.GetString("CastBar_ComplexLabel"), self.tCurrentOpSpell.strName, strExtra)) -- todo: Set the name once we have a function for it
end

------------------------------------------------------------------------
-- New Buff and Debuff Lua Code
------------------------------------------------------------------------

function CastBar:OnGenerateTooltip(wndHandler, wndControl, eType, spl)
	if wndControl == wndHandler then
		return nil
	end
	Tooltip.GetBuffTooltipForm(self, wndControl, spl)
end

------------------------------------------------------------------------
-- Spell Threshold Lua Code
------------------------------------------------------------------------

function CastBar:OnStartSpellThreshold(idSpell, nMaxThresholds, eCastMethod) -- also fires on tier change
	if self.tCurrentOpSpell ~= nil and idSpell == self.tCurrentOpSpell.id then return end -- we're getting an update event, ignore this one

	self.tCurrentOpSpell = {}
	local splObject = GameLib.GetSpell(idSpell)

	self.tCurrentOpSpell.id = idSpell
	self.tCurrentOpSpell.nCurrentTier = 1
	self.tCurrentOpSpell.nMaxTier = nMaxThresholds
	self.tCurrentOpSpell.eCastMethod = eCastMethod
	self.tCurrentOpSpell.strName = splObject:GetName()

	-- hide all UI elements
	self.wndOppBarCircle:Show(false)
	self.wndOppBar:Show(false)
	for idx = 1, self.tCurrentOpSpell.nMaxTier do
		self.tTierMarks[idx]:Show(false)
		self.tTierMarks[idx]:FindChild("MarkerBacker"):SetSprite(self.arTierSprites[idx].strMarkEmpty)
		self.tTierMarks[idx]:FindChild("Marker"):SetSprite("")
	end
	self.wndOppBarTiered:Show(false)

	-- restart the progress bar; we'll have to add enum types as they come online
	if self.tCurrentOpSpell.eCastMethod == Spell.CodeEnumCastMethod.RapidTap then
		self.wndOppBarCircle:Show(true)
	elseif self.tCurrentOpSpell.eCastMethod == Spell.CodeEnumCastMethod.PressHold then
		self.wndOppBar:Show(true)
	elseif self.tCurrentOpSpell.eCastMethod == Spell.CodeEnumCastMethod.ChargeRelease then
		-- set up the tier marks
		for idx = 1, self.tCurrentOpSpell.nMaxTier do
			self.tTierMarks[idx]:Show(true)
			self.tTierMarks[idx]:FindChild("MarkerBacker"):SetSprite(self.arTierSprites[idx].strMarkEmpty)
			self.tTierMarks[idx]:FindChild("Marker"):SetSprite("")
		end

		self.wndOppBarTiered:FindChild("TierMarkContainer"):ArrangeChildrenHorz(1)

		self.wndOppBarTiered:Show(true)
	end

	self.wndOppFrame:Show(true)

	-- Do the initial update so the first tier is lit up correctly
	self:OnUpdateSpellThreshold(idSpell, self.tCurrentOpSpell.nCurrentTier)
end

function CastBar:OnUpdateSpellThreshold(idSpell, nNewThreshold) -- Updates when P/H/R changes tier or RT tap is performed
	if self.tCurrentOpSpell == nil or idSpell ~= self.tCurrentOpSpell.id then return end

	self.tCurrentOpSpell.nCurrentTier = nNewThreshold
	self.tTierMarks[nNewThreshold]:FindChild("Marker"):SetSprite(self.arTierSprites[nNewThreshold].strMarkFull)
	self.tTierMarks[nNewThreshold]:FindChild("Flash"):SetSprite("CRB_CastBarSprites:sprCB_PHRMarkerFlash")
	self.wndOppBarTiered:FindChild("AlertFlash2"):SetSprite("CRB_CastBarSprites:sprCB_Fill_Flash")
	self.wndOppBarCircle:FindChild("AlertFlash"):SetSprite("CRB_Basekit:kitAccent_Glow_GoldFlash")
end

function CastBar:OnClearSpellThreshold(idSpell)
	if self.tCurrentOpSpell ~= nil and idSpell ~= self.tCurrentOpSpell.id then return end -- different spell got loaded up before the previous was cleared. this is valid.

	self.wndOppFrame:Show(false)
	self.wndOppBar:Show(false)
	self.wndOppBarCircle:Show(false)
	self.wndOppBarTiered:Show(false)
	self.wndOppBarTiered:FindChild("AlertFlash2"):SetSprite("")
	self.wndOppBarCircle:FindChild("AlertFlash"):SetSprite("")
	self.tCurrentOpSpell = nil
	for i = 1, knMaxTiers do
		self.tTierMarks[i]:Show(false)
	end
end

local CastBarInstance = CastBar:new()
CastBarInstance:Init()
Offset="0" BAnchorPoint="0" BAnchorOffset="51" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="CategoryFilterItem" BGColor="white" TextColor="white" TooltipColor="" IgnoreMouse="1" Overlapped="1" TooltipFont="CRB_InterfaceSmall_O" Tooltip="">
        <Control Class="Button" Base="BK3:btnMetal_ExpandMenu_Small" Font="CRB_InterfaceMedium_B" ButtonType="Check" RadioGroup="" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" DT_VCENTER="1" DT_CENTER="1" TooltipType="OnCursor" Name="CategoryFilterBtn" BGColor="white" TextColor="white" TooltipColor="" NormalTextColor="UI_TextHoloBody" PressedTextColor="UI_BtnTextHoloPressed" FlybyTextColor="UI_BtnTextHoloFlyby" PressedFlybyTextColor="UI_BtnTextHoloPressedFlyby" DisabledTextColor="UI_BtnTextHoloDisabled" Text="" TextId="" GlobalRadioGroup="BuilderMap_CategoryFilterBtn_GlobalRadioGroup" RadioDisallowNonSelection="0" RelativeToClient="1" IgnoreMouse="1" WindowSoundTemplate="MetalButtonLarge">
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="10" TAnchorPoint="0" TAnchorOffset="-2" RAnchorPoint="1" RAnchorOffset="-20" BAnchorPoint="0" BAnchorOffset="32" RelativeToClient="1" Font="CRB_InterfaceMedium_B" Text="" Template="Default" TooltipType="OnCursor" Name="CategoryFilterName" BGColor="white" TextColor="UI_BtnTextGoldListNormal" TooltipColor="" TextId="SettlerAvenueType_Security" DT_CENTER="0" DT_VCENTER="1"/>
            <Control Class="Window" LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="1" TAnchorOffset="-18" RAnchorPoint="1" RAnchorOffset="-38" BAnchorPoint="1" BAnchorOffset="0" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="CategoryFilterBarBG" BGColor="white" TextColor="white" TooltipColor="" Sprite="CRB_Basekit:kitIProgBar_Inlay_Base" Picture="1" IgnoreMouse="1" NewControlDepth="1"/>
            <Control Class="ProgressBar" Text="" LAnchorPoint="0" LAnchorOffset="12" TAnchorPoint="1" TAnchorOffset="-19" RAnchorPoint="1" RAnchorOffset="-42" BAnchorPoint="1" BAnchorOffset="0" AutoSetText="0" UseValues="0" RelativeToClient="1" SetTextToProgress="0" DT_CENTER="1" DT_VCENTER="1" ProgressEmpty="" ProgressFull="CRB_Basekit:kitIProgBar_Simple_Fill" TooltipType="OnCursor" Name="CategoryFilterBar" BGColor="white" TextColor="white" TooltipColor="" BarColor="" Sprite="CRB_Basekit:kitIProgBar_Simple_Fill" Picture="0" IgnoreMouse="1" TooltipFont="CRB_InterfaceSmall_O"/>
            <Event Name="ButtonCheck" Function="OnCategoryFilterBtnCheck"/>
            <Event Name="ButtonUncheck" Function="OnCategoryFilterBtnUncheck"/>
        </Control>
    </Form>
    <Form Class="Window" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="0" BAnchorOffset="60" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="SelectionItem" BGColor="white" TextColor="white" TooltipColor="" HideInEditor="0" IgnoreMouse="1" Overlapped="1" TooltipFont="CRB_InterfaceSmall" Tooltip="">
        <Control Class="Button" Base="CRB_Basekit:kitBtn_List_MetalBorder" Font="Thick" ButtonType="Check" RadioGroup="" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" DT_VCENTER="1" DT_CENTER="1" TooltipType="OnCursor" Name="SelectionItemBtn" BGColor="white" TextColor="white" TooltipColor="" NormalTextColor="white" PressedTextColor="white" FlybyTextColor="white" PressedFlybyTextColor="white" DisabledTextColor="white" Picture="1" Sprite="" RelativeToClient="1" TestAlpha="1" GlobalRadioGroup="BuilderMap_SelectionItemBtn_GlobalRadioGroup" Text="" Tooltip="" TooltipF