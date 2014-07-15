-----------------------------------------------------------------------------------------------
-- Client Lua Script for ActionBarFrame
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "GameLib"
require "Spell"
require "Unit"
require "Item"
require "PlayerPathLib"
require "AbilityBook"
require "ActionSetLib"
require "AttributeMilestonesLib"
require "Tooltip"

local ActionBarFrame = {}

function ActionBarFrame:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ActionBarFrame:Init()
    Apollo.RegisterAddon(self)
end

function ActionBarFrame:OnLoad()
	g_ActionBarLoaded = false
	
	self.nSelectedMount = nil
	self.nSelectedPotion = nil
	
	self.xmlDoc = XmlDoc.CreateFromFile("ActionBarFrame.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ActionBarFrame:OnDocumentReady()
	Apollo.RegisterEventHandler("UnitEnteredCombat", 						"OnUnitEnteredCombat", self)
	Apollo.RegisterEventHandler("PlayerChanged", 							"InitializeBars", self)
	Apollo.RegisterEventHandler("WindowSizeChanged", 						"InitializeBars", self)
	Apollo.RegisterEventHandler("OptionsUpdated_HUDPreferences", 			"InitializeBars", self)
	Apollo.RegisterEventHandler("PlayerLevelChange", 						"InitializeBars", self)

	Apollo.RegisterEventHandler("CharacterCreated", 						"OnCharacterCreated", self)
	
	Apollo.RegisterEventHandler("AbilityBookChange",						"RedrawMounts", self)
	Apollo.RegisterEventHandler("StanceChanged", 							"RedrawStances", self)
	
	Apollo.RegisterEventHandler("ShowActionBarShortcut", 					"OnShowActionBarShortcut", self)
	Apollo.RegisterEventHandler("ShowActionBarShortcutDocked", 				"OnShowActionBarShortcutDocked", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 				"OnTutorial_RequestUIAnchor", self)
	Apollo.RegisterEventHandler("Options_UpdateActionBarTooltipLocation", 	"OnUpdateActionBarTooltipLocation", self)
	Apollo.RegisterEventHandler("ActionBarNonSpellShortcutAddFailed", 		"OnActionBarNonSpellShortcutAddFailed", self)
	Apollo.RegisterEventHandler("UpdateInventory", 							"OnUpdateInventory", self)

	self.wndShadow = Apollo.LoadForm(self.xmlDoc, "Shadow", "FixedHudStratumLow", self)
	self.wndArt = Apollo.LoadForm(self.xmlDoc, "Art", "FixedHudStratumLow", self)
	self.wndBar2 = Apollo.LoadForm(self.xmlDoc, "Bar2ButtonContainer", "FixedHudStratum", self)
	self.wndBar3 = Apollo.LoadForm(self.xmlDoc, "Bar3ButtonContainer", "FixedHudStratum", self)

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "ActionBarFrameForm", "FixedHudStratum", self)
	self.wndBar1 = self.wndMain:FindChild("Bar1ButtonContainer")

	self.wndStancePopoutFrame = self.wndMain:FindChild("StancePopoutFrame")
	self.wndMain:FindChild("StancePopoutBtn"):AttachWindow(self.wndStancePopoutFrame)

	self.wndPotionFlyout = self.wndMain:FindChild("PotionFlyout")
	self.wndPotionPopoutFrame = self.wndPotionFlyout:FindChild("PotionPopoutFrame")
	self.wndMain:FindChild("PotionPopoutBtn"):AttachWindow(self.wndPotionPopoutFrame)

	g_wndActionBarResources	= Apollo.LoadForm(self.xmlDoc, "Resources", "FixedHudStratumLow", self) -- Do not rename. This is global and used by other forms as a parent.

	Event_FireGenericEvent("ActionBarLoaded")
	
	self.wndMountFlyout = Apollo.LoadForm(self.xmlDoc, "MountFlyout", nil, self)
	self.wndMountFlyout:FindChild("MountPopoutBtn"):AttachWindow(self.wndMountFlyout:FindChild("MountPopoutFrame"))

	self.wndArt:Show(false)
	self.wndMain:Show(false)
	self.wndMountFlyout:Show(false)
	self.wndPotionFlyout:Show(false)

	-- TODO: Figure out why Stances, Mounts and Potions break w/o this hack.
	Apollo.RegisterTimerHandler("ActionBarFrameTimer_DelayedInit", "OnCharacterCreated", self)
	Apollo.CreateTimer("ActionBarFrameTimer_DelayedInit", 0.5, false)
	Apollo.StartTimer("ActionBarFrameTimer_DelayedInit")
	
	g_ActionBarLoaded = true

	if GameLib.GetPlayerUnit() ~= nil then
		self:OnCharacterCreated()
	end
end

function ActionBarFrame:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSavedData =
	{
		nSelectedMount = self.nSelectedMount,
		nSelectedPotion = self.nSelectedPotion,
		tVehicleBar = self.tCurrentVehicleInfo
	}

	return tSavedData
end

function ActionBarFrame:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	if tSavedData.nSelectedMount then
		self.nSelectedMount = tSavedData.nSelectedMount
	end

	if tSavedData.nSelectedPotion then
		self.nSelectedPotion = tSavedData.nSelectedPotion
	end
	
	if tSavedData.tVehicleBar then
		self.tCurrentVehicleInfo = tSavedData.tVehicleBar
	end
end

function ActionBarFrame:OnPlayerEquippedItemChanged()
	local nVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")
	if (nVisibility == nil or nVisibility < 1) and self:IsWeaponEquipped() then
		Event_FireGenericEvent("OptionsUpdated_HUDTriggerTutorial", "skillsBarDisplay")
	end
end

function ActionBarFrame:IsWeaponEquipped()
	local unitPlayer = GameLib.GetPlayerUnit()
	
	local tEquipment = unitPlayer and unitPlayer:IsValid() and unitPlayer:GetEquippedItems() or {}
	for idx, tItemData in pairs(tEquipment) do
		if tItemData:GetSlot() == 16 then
			return true
		end
	end

	return false
end

function ActionBarFrame:OnUnitEnteredCombat(unit)
	if unit ~= GameLib.GetPlayerUnit() then
		return
	end
	
	self:RedrawBarVisibility()
end

function ActionBarFrame:InitializeBars()
	self:RedrawStances()
	self:RedrawMounts()
	self:RedrawPotions()

	local nVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")

	if nVisibility == nil or nVisibility < 1 then
		local bHasWeaponEquipped = self:IsWeaponEquipped()

		if bHasWeaponEquipped then
			-- This isn't a new character, set the preference to always display.
			Apollo.SetConsoleVariable("hud.skillsBarDisplay", 1)
		else
			-- Wait for the player to equip their first item
			Apollo.RegisterEventHandler("PlayerEquippedItemChanged", 	"OnPlayerEquippedItemChanged", self)
		end
	end

	self.wndArt:Show(true)
	self.wndMain:Show(true)
	self.wndBar1:DestroyChildren()
	self.wndBar2:DestroyChildren()
	self.wndBar3:DestroyChildren()

	-- All the buttons
	self.arBarButtons = {}
	self.arBarButtons[0] = self.wndMain:FindChild("ActionBarInnate")

	for idx = 1, 34 do
		local wndCurr = nil
		local wndActionBarBtn = nil

		if idx < 9 then
			wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemBig", self.wndBar1, self)
			wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
			wndActionBarBtn:SetContentId(idx - 1)

			if ActionSetLib.IsSlotUnlocked(idx - 1) ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok then
				wndCurr:FindChild("LockSprite"):Show(true)
				wndCurr:FindChild("Cover"):Show(false)
				wndCurr:FindChild("Shadow"):Show(false)
			else
				wndCurr:FindChild("LockSprite"):Show(false)
				wndCurr:FindChild("Cover"):Show(true)
				wndCurr:FindChild("Shadow"):Show(true)
			end
		elseif idx < 11 then -- 9 to 10
			wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemMed", self.wndMain:FindChild("Bar1ButtonSmallContainer:Buttons"), self)
			wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
			wndActionBarBtn:SetContentId(idx - 1)

			wndCurr:FindChild("LockSprite"):Show(false)
			wndCurr:FindChild("Cover"):Show(true)
			wndCurr:FindChild("Shadow"):Show(true)

			if ActionSetLib.IsSlotUnlocked(idx - 1) ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok then
				wndCurr:SetTooltip(idx == 9 and Apollo.GetString("ActionBarFrame_LockedGadgetSlot") or Apollo.GetString("ActionBarFrame_LockedPathSlot"))
			end
		elseif idx < 23 then -- 11 to 22
			wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemSmall", self.wndBar2, self)
			wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
			wndActionBarBtn:SetContentId(idx + 1)

			--hide bars we can't draw due to screen size
			if (idx - 10) * wndCurr:GetWidth() > self.wndBar2:GetWidth() and self.wndBar2:GetWidth() > 0 then
				wndCurr:Show(false)
			end
		else -- 23 to 34
			wndCurr = Apollo.LoadForm(self.xmlDoc, "ActionBarItemSmall", self.wndBar3, self)
			wndActionBarBtn = wndCurr:FindChild("ActionBarBtn")
			wndActionBarBtn:SetContentId(idx + 1)

			--hide bars we can't draw due to screen size
			if (idx - 22) * wndCurr:GetWidth() > self.wndBar3:GetWidth() and self.wndBar3:GetWidth() > 0 then
				wndCurr:Show(false)
			end
		end
		self.arBarButtons[idx] = wndActionBarBtn
	end

	self.wndBar1:ArrangeChildrenHorz(0)
	self.wndMain:FindChild("Bar1ButtonSmallContainer:Buttons"):ArrangeChildrenHorz(0)
	self.wndBar2:ArrangeChildrenHorz(0)
	self.wndBar3:ArrangeChildrenHorz(0)
	self:OnUpdateActionBarTooltipLocation()

	self:RedrawBarVisibility()
end

function ActionBarFrame:RedrawBarVisibility()
	local unitPlayer = GameLib.GetPlayerUnit()
	local bActionBarShown = self.wndMain:IsShown()

	--Toggle Visibility based on ui preference
	local nSkillsVisibility = Apollo.GetConsoleVariable("hud.skillsBarDisplay")
	local nLeftVisibility = Apollo.GetConsoleVariable("hud.secondaryLeftBarDisplay")
	local nRightVisibility = Apollo.GetConsoleVariable("hud.secondaryRightBarDisplay")
	local nResourceVisibility = Apollo.GetConsoleVariable("hud.resourceBarDisplay")
	local nMountVisibility = Apollo.GetConsoleVariable("hud.mountButtonDisplay")

	if nSkillsVisibility == 1 then --always on
		self.wndMain:Show(true)
	elseif nSkillsVisibility == 2 then --always off
		self.wndMain:Show(false)
	elseif nSkillsVisibility == 3 then --on in combat
		self.wndMain:Show(unitPlayer and unitPlayer:IsInCombat())
	elseif nSkillsVisibility == 4 then --on out of combat
		self.wndMain:Show(unitPlayer and not unitPlayer:IsInCombat())
	else
		self.wndMain:Show(false)
	end

	if nResourceVisibility == nil or nResourceVisibility < 1 then
		g_wndActionBarResources:Show(bActionBarShown)
	else
		g_wndActionBarResources:Show(true)
	end

	if nLeftVisibility == 1 then --always on
		self.wndBar2:Show(true)
	elseif nLeftVisibility == 2 then --always off
		self.wndBar2:Show(false)
	elseif nLeftVisibility == 3 then --on in combat
		self.wndBar2:Show(unitPlayer and unitPlayer:IsInCombat())
	elseif nLeftVisibility == 4 then --on out of combat
		self.wndBar2:Show(unitPlayer and not unitPlayer:IsInCombat())
	else
		--NEW Player Experience: Set the bottom left/right bars to Always Show once you've reached level 3
		if unitPlayer and (unitPlayer:GetLevel() or 1) > 2 then
			--Trigger a HUD Tutorial
			Event_FireGenericEvent("OptionsUpdated_HUDTriggerTutorial", "secondaryLeftBarDisplay")
		end

		self.wndBar2:Show(false)
	end

	if nRightVisibility == 1 then --always on
		self.wndBar3:Show(true)
	elseif nRightVisibility == 2 then --always off
		self.wndBar3:Show(false)
	elseif nRightVisibility == 3 then --on in combat
		self.wndBar3:Show(unitPlayer and unitPlayer:IsInCombat())
	elseif nRightVisibility == 4 then --on out of combat
		self.wndBar3:Show(unitPlayer and not unitPlayer:IsInCombat())
	else
		--NEW Player Experience: Set the bottom left/right bars to Always Show once you've reached level 3
		if unitPlayer and (unitPlayer:GetLevel() or 1) > 2 then
			--Trigger a HUD Tutorial
			Event_FireGenericEvent("OptionsUpdated_HUDTriggerTutorial", "secondaryRightBarDisplay")
		end

		self.wndBar3:Show(false)
	end

	if next(self.wndMountFlyout:FindChild("MountPopoutList"):GetChildren()) ~= nil then
		if nMountVisibility == 2 then --always off
			self.wndMountFlyout:Show(false)
		elseif nMountVisibility == 3 then --on in combat
			self.wndMountFlyout:Show(unitPlayer and unitPlayer:IsInCombat())
		elseif nMountVisibility == 4 then --on out of combat
			self.wndMountFlyout:Show(unitPlayer and not unitPlayer:IsInCombat())
		else
			self.wndMountFlyout:Show(true)
		end
	else
		self.wndMountFlyout:Show(false)
	end

	local bActionBarShown = self.wndMain:IsShown()
	local bFloatingActionBarShown = self.wndArt:FindChild("BarFrameShortcut"):IsShown()

	self.wndShadow:SetOpacity(0.5)
	self.wndShadow:Show(true)
	self.wndArt:Show(bActionBarShown)
	self.wndPotionFlyout:Show(self.wndPotionFlyout:IsShown() and unitPlayer and not unitPlayer:IsInVehicle())

	local nLeft, nTop, nRight, nBottom = g_wndActionBarResources:GetAnchorOffsets()

	if bActionBarShown then
		local nOffset = bFloatingActionBarShown and -173 or -103
		
		g_wndActionBarResources:SetAnchorOffsets(nLeft, nTop, nRight, nOffset)
	else
		g_wndActionBarResources:SetAnchorOffsets(nLeft, nTop, nRight, -19)
	end
end

-----------------------------------------------------------------------------------------------
-- Main Redraw
-----------------------------------------------------------------------------------------------
function ActionBarFrame:RedrawStances()
	local wndStancePopout = self.wndStancePopoutFrame:FindChild("StancePopoutList")
	wndStancePopout:DestroyChildren()

	local nCountSkippingTwo = 0
	for idx, spellObject in pairs(GameLib.GetClassInnateAbilitySpells().tSpells) do
		if idx % 2 == 1 then
			nCountSkippingTwo = nCountSkippingTwo + 1
			local strKeyBinding = GameLib.GetKeyBinding("SetStance"..nCountSkippingTwo) -- hardcoded formatting
			local wndCurr = Apollo.LoadForm(self.xmlDoc, "StanceBtn", wndStancePopout, self)
			wndCurr:FindChild("StanceBtnKeyBind"):SetText(strKeyBinding == "<Unbound>" and "" or strKeyBinding)
			wndCurr:FindChild("StanceBtnIcon"):SetSprite(spellObject:GetIcon())
			wndCurr:SetData(nCountSkippingTwo)

			if Tooltip and Tooltip.GetSpellTooltipForm then
				wndCurr:SetTooltipDoc(nil)
				Tooltip.GetSpellTooltipForm(self, wndCurr, spellObject)
			end
		end
	end

	local nHeight = wndStancePopout:ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = self.wndStancePopoutFrame:GetAnchorOffsets()
	self.wndStancePopoutFrame:SetAnchorOffsets(nLeft, nBottom - nHeight - 98, nRight, nBottom)
	self.wndMain:FindChild("StancePopoutBtn"):Show(#wndStancePopout:GetChildren() > 0)
end

function ActionBarFrame:OnStanceBtn(wndHandler, wndControl)
	self.wndMain:FindChild("StancePopoutFrame"):Show(false)
	GameLib.SetCurrentClassInnateAbilityIndex(wndHandler:GetData())
end

function ActionBarFrame:RedrawSelectedMounts()
	GameLib.SetShortcutMount(self.nSelectedMount)
end

function ActionBarFrame:RedrawMounts()
	local wndPopoutFrame = self.wndMountFlyout:FindChild("MountPopoutFrame")
	local wndMountPopout = wndPopoutFrame:FindChild("MountPopoutList")
	wndMountPopout:DestroyChildren()

	local tMountList = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Mount) or {}
	local tSelectedSpellObj = nil

	for idx, tMountData  in pairs(tMountList) do
		local tSpellObject = tMountData.tTiers[1].splObject

		if tSpellObject:GetId() == self.nSelectedMount then
			tSelectedSpellObj = tSpellObject
		end

		local wndCurr = Apollo.LoadForm(self.xmlDoc, "MountBtn", wndMountPopout, self)
		wndCurr:FindChild("MountBtnIcon"):SetSprite(tSpellObject:GetIcon())
		wndCurr:SetData(tSpellObject)

		if Tooltip and Tooltip.GetSpellTooltipForm then
			wndCurr:SetTooltipDoc(nil)
			Tooltip.GetSpellTooltipForm(self, wndCurr, tSpellObject, {})
		end
	end

	if tSelectedSpellObj == nil and #tMountList > 0 then
		tSelectedSpellObj = tMountList[1].tTiers[1].splObject
	end

	if tSelectedSpellObj ~= nil then
		GameLib.SetShortcutMount(tSelectedSpellObj:GetId())
	end

	local nCount = #wndMountPopout:GetChildren()
	if nCount > 0 then
		local nMax = 7
		local nMaxHeight = (wndMountPopout:ArrangeChildrenVert(0) / nCount) * nMax
		local nHeight = wndMountPopout:ArrangeChildrenVert(0)

		nHeight = nHeight <= nMaxHeight and nHeight or nMaxHeight

		local nLeft, nTop, nRight, nBottom = wndPopoutFrame:GetAnchorOffsets()

		wndPopoutFrame:SetAnchorOffsets(nLeft, nBottom - nHeight - 98, nRight, nBottom)
		self:RedrawBarVisibility()
	else
		self.wndMountFlyout:Show(false)
	end
end

function ActionBarFrame:OnMountBtn(wndHandler, wndControl)
	self.nSelectedMount = wndControl:GetData():GetId()

	self.wndMountFlyout:FindChild("MountPopoutFrame"):Show(false)
	self:RedrawSelectedMounts()
end

function ActionBarFrame:RedrawPotions()
	local unitPlayer = GameLib.GetPlayerUnit()
	
	local wndPotionPopout = self.wndPotionPopoutFrame:FindChild("PotionPopoutList")
	wndPotionPopout:DestroyChildren()

	local tItemList = unitPlayer and unitPlayer:IsValid() and unitPlayer:GetInventoryItems() or {}
	local tSelectedPotion = nil;
	local tFirstPotion = nil
	local tPotions = { }
	
	for idx, tItemData in pairs(tItemList) do
		if tItemData and tItemData.itemInBag and tItemData.itemInBag:GetItemCategory() == 48 then--and tItemData.itemInBag:GetConsumable() == "Consumable" then
			local itemPotion = tItemData.itemInBag

			if tFirstPotion == nil then
				tFirstPotion = itemPotion
			end

			if itemPotion:GetItemId() == self.nSelectedPotion then
				tSelectedPotion = itemPotion
			end
			
			local idItem = itemPotion:GetItemId()

			if tPotions[idItem] == nil then
				tPotions[idItem] = 
				{
					itemObject = itemPotion,
					nCount = itemPotion:GetStackCount(),
				}
			else
				tPotions[idItem].nCount = tPotions[idItem].nCount + itemPotion:GetStackCount()
			end
		end
	end

	for idx, tData  in pairs(tPotions) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "PotionBtn", wndPotionPopout, self)
		wndCurr:FindChild("PotionBtnIcon"):SetSprite(tData.itemObject:GetIcon())
		if (tData.nCount > 1) then wndCurr:FindChild("PotionBtnStackCount"):SetText(tData.nCount) end
		wndCurr:SetData(tData.itemObject)

		wndCurr:SetTooltipDoc(nil)
		Tooltip.GetItemTooltipForm(self, wndCurr, tData.itemObject, {})
	end

	if tSelectedPotion == nil and tFirstPotion ~= nil then
		tSelectedPotion = tFirstPotion
	end

	if tSelectedPotion ~= nil then
		GameLib.SetShortcutPotion(tSelectedPotion:GetItemId())
	end

	local nCount = #wndPotionPopout:GetChildren()
	if nCount > 0 then
		local nMax = 7
		local nMaxHeight = (wndPotionPopout:ArrangeChildrenVert(0) / nCount) * nMax
		local nHeight = wndPotionPopout:ArrangeChildrenVert(0)

		nHeight = nHeight <= nMaxHeight and nHeight or nMaxHeight

		local nLeft, nTop, nRight, nBottom = self.wndPotionPopoutFrame:GetAnchorOffsets()

		self.wndPotionPopoutFrame:SetAnchorOffsets(nLeft, nBottom - nHeight - 98, nRight, nBottom)
	end

	self.wndPotionFlyout:Show(nCount > 0)
end

function ActionBarFrame:OnPotionBtn(wndHandler, wndControl)
	self.nSelectedPotion = wndControl:GetData():GetItemId()

	self.wndPotionPopoutFrame:Show(false)
	self:RedrawPotions()
end

function ActionBarFrame:OnShowActionBarShortcut(nWhichBar, bIsVisible, nNumShortcuts)
	if nWhichBar == 0 and self.wndMain and self.wndMain:IsValid() then
		if self.arBarButtons then
			for idx, wndBtn in pairs(self.arBarButtons) do
				wndBtn:Enable(not bIsVisible) -- Turn on or off all buttons
			end
		end
		
		self:ShowVehicleBar(nWhichBar, bIsVisible, nNumShortcuts) -- show/hide vehicle bar if nWhichBar matches
	end
end

function ActionBarFrame:OnShowActionBarShortcutDocked(bVisible)
	self.wndArt:FindChild("BarFrameShortcut"):Show(bVisible, not bVisible)
	self:RedrawBarVisibility()
end

function ActionBarFrame:ShowVehicleBar(nWhichBar, bIsVisible, nNumShortcuts)
	if nWhichBar ~= 0 or not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndVehicleBar = self.wndMain:FindChild("VehicleBarMain")
	wndVehicleBar:Show(bIsVisible)

	self.wndMain:FindChild("StanceFlyout"):Show(not bIsVisible)
	self.wndMain:FindChild("Bar1ButtonSmallContainer"):Show(not bIsVisible)

	self.wndBar1:Show(not bIsVisible)
	
	self.tCurrentVehicleInfo = nil

	if bIsVisible then
		for idx = 1, 6 do -- TODO hardcoded formatting
			wndVehicleBar:FindChild("ActionBarShortcutContainer" .. idx):Show(false)
		end

		if nNumShortcuts then
			for idx = 1, math.max(2, nNumShortcuts) do -- Art width does not support just 1
				wndVehicleBar:FindChild("ActionBarShortcutContainer" .. idx):Show(true)
				wndVehicleBar:FindChild("ActionBarShortcutContainer" .. idx):FindChild("ActionBarShortcut." .. idx):Enable(true)
			end

			local nLeft, nTop ,nRight, nBottom = wndVehicleBar:FindChild("VehicleBarFrame"):GetAnchorOffsets() -- TODO SUPER HARDCODED FORMATTING
			wndVehicleBar:FindChild("VehicleBarFrame"):SetAnchorOffsets(nLeft, nTop, nLeft + (58 * nNumShortcuts) + 66, nBottom)
		end

		wndVehicleBar:ArrangeChildrenHorz(1)
		
		self.tCurrentVehicleInfo =
		{
			nBar = nWhichBar,
			nNumShortcuts = nNumShortcuts,
		}
	end
end

function ActionBarFrame:OnUpdateActionBarTooltipLocation()
	for idx = 0, 10 do
		self:HelperSetTooltipType(self.arBarButtons[idx])
	end
end

function ActionBarFrame:HelperSetTooltipType(wnd)
	if Apollo.GetConsoleVariable("ui.actionBarTooltipsOnCursor") then
		wnd:SetTooltipType(Window.TPT_OnCursor)
	else
		wnd:SetTooltipType(Window.TPT_DynamicFloater)
	end
end

function ActionBarFrame:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor == GameLib.CodeEnumTutorialAnchor.AbilityBar or eAnchor == GameLib.CodeEnumTutorialAnchor.InnateAbility then
		local tRect = {}
		tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()
		Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
	end
end

function ActionBarFrame:OnUpdateInventory()
	local unitPlayer = GameLib.GetPlayerUnit()
	
	if self.nPotionCount == nil then
		self.nPotionCount = 0
	end

	local nLastPotionCount = self.nPotionCount
	local tItemList = unitPlayer and unitPlayer:IsValid() and unitPlayer:GetInventoryItems() or {}
	local tPotions = { }

	for idx, tItemData in pairs(tItemList) do
		if tItemData and tItemData.itemInBag and tItemData.itemInBag:GetItemCategory() == 48 then--and tItemData.itemInBag:GetConsumable() == "Consumable" then
			local tItem = tItemData.itemInBag

			if tPotions[tItem:GetItemId()] == nil then
				tPotions[tItem:GetItemId()] = {}
				tPotions[tItem:GetItemId()].nCount=tItem:GetStackCount()
			else
				tPotions[tItem:GetItemId()].nCount = tPotions[tItem:GetItemId()].nCount + tItem:GetStackCount()
			end
		end
	end

	self.nPotionCount = 0
	for idx, tItemData in pairs(tPotions) do
		self.nPotionCount = self.nPotionCount + 1
	end

	if self.nPotionCount ~= nLastPotionCount then
		self:RedrawPotions()
	end
end

function ActionBarFrame:OnGenerateTooltip(wndControl, wndHandler, eType, arg1, arg2)
	local xml = nil
	if eType == Tooltip.TooltipGenerateType_ItemInstance then -- Doesn't need to compare to item equipped
		Tooltip.GetItemTooltipForm(self, wndControl, arg1, {})
	elseif eType == Tooltip.TooltipGenerateType_ItemData then -- Doesn't need to compare to item equipped
		Tooltip.GetItemTooltipForm(self, wndControl, arg1, {})
	elseif eType == Tooltip.TooltipGenerateType_GameCommand then
		xml = XmlDoc.new()
		xml:AddLine(arg2)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Macro then
		xml = XmlDoc.new()
		xml:AddLine(arg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Spell then
		if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
			Tooltip.GetSpellTooltipForm(self, wndControl, arg1)
		end
	elseif eType == Tooltip.TooltipGenerateType_PetCommand then
		xml = XmlDoc.new()
		xml:AddLine(arg2)
		wndControl:SetTooltipDoc(xml)
	end
end

function ActionBarFrame:OnActionBarNonSpellShortcutAddFailed()
	--TODO: Print("You can not add that to your Limited Action Set bar.")
end

function ActionBarFrame:OnCharacterCreated()
	local unitPlayer = GameLib.GetPlayerUnit()
	
	if GameLib.IsCharacterLoaded() and not self.bCharacterLoaded and unitPlayer and unitPlayer:IsValid() then
		self.bCharacterLoaded = true
		Apollo.StopTimer("ActionBarFrameTimer_DelayedInit")
		Event_FireGenericEvent("ActionBarReady", self.wndMain)
		self:InitializeBars()
		
		if self.tCurrentVehicleInfo and unitPlayer:IsInVehicle() then
			self:OnShowActionBarShortcut(self.tCurrentVehicleInfo.nBar, true, self.tCurrentVehicleInfo.nNumShortcuts)
		else
			self.tCurrentVehicleInfo = nil
		end
	else
		Apollo.StartTimer("ActionBarFrameTimer_DelayedInit")
	end
end

local ActionBarFrameInst = ActionBarFrame:new()
ActionBarFrameInst:Init()
