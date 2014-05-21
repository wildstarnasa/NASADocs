-----------------------------------------------------------------------------------------------
-- Client Lua Script for Abilities
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Spell"
require "ActionSetLib"
require "AbilityBook"
require "Tooltip"

local Abilities = {}

function Abilities:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Abilities:Init()
    Apollo.RegisterAddon(self)
end

function Abilities:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("AbilitiesBuilder.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Abilities:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 					"OnInterfaceMenuListHasLoaded", self)

	Apollo.RegisterEventHandler("PlayerCurrencyChanged", 						"DrawSpellBook", self)
	Apollo.RegisterEventHandler("AbilityBookChange", 							"DrawSpellBook", self)
	Apollo.RegisterEventHandler("PlayerLevelChange", 							"DrawSpellBook", self)
	Apollo.RegisterEventHandler("SpecChanged", 									"OnSpecChanged", self)
	Apollo.RegisterEventHandler("ActionSetError", 								"OnActionSetError", self)
	Apollo.RegisterEventHandler("AbilityAMPs_ToggleDirtyBit", 					"OnToggleDirtyBit", self)

	Apollo.RegisterEventHandler("PlayerChanged", 								"OnCharacterCreated", self)
	Apollo.RegisterEventHandler("CharacterCreated", 							"OnCharacterCreated", self)
	Apollo.RegisterEventHandler("ToggleAbilitiesWindow", 						"OnToggleAbilitiesWindow", self)
	Apollo.RegisterEventHandler("Tutorial_RequestUIAnchor", 					"OnTutorial_RequestUIAnchor", self)

	Apollo.RegisterEventHandler("LevelUpUnlock_AMPSystem",						"OnLevelUpUnlock_AMPSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_AMPPoint",						"OnLevelUpUnlock_AMPSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_TierPointSystem",				"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_NewTierPoint",					"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_LASSlot2",						"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_LASSlot3",						"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_LASSlot4",						"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_LASSlot5",						"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_LASSlot6",						"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_LASSlot7",						"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_LASSlot8",						"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_AbilityTier2",					"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_AbilityTier3",					"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_AbilityTier4",					"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_AbilityTier5",					"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_AbilityTier6",					"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_AbilityTier7",					"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_AbilityTier8",					"OnLevelUpUnlock_TierPointSystem", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Class_Ability",					"OnLevelUpUnlock_Class_Ability", self)
	Apollo.RegisterEventHandler("LevelUpUnlock_Path_Spell",						"OnLevelUpUnlock_Path_Spell", self)

	Apollo.RegisterTimerHandler("AbilitiesBuilder_HideErrorContainerTimer", 	"OnErrorContainerHideBtn", self)
end

function Abilities:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_AbilityBuilder"), {"ToggleAbilitiesWindow", "LimitedActionSetBuilder", "Icon_Windows32_UI_CRB_InterfaceMenu_Abilities"})
	self:UpdateInterfaceMenuAlerts()
end

function Abilities:UpdateInterfaceMenuAlerts()
	local nPoints = GameLib.GetAbilityPoints() + AbilityBook.GetAvailablePower()
	Event_FireGenericEvent("InterfaceMenuList_AlertAddOn", Apollo.GetString("InterfaceMenu_AbilityBuilder"), {nPoints > 0, nil, nPoints})
end

function Abilities:OnToggleAbilitiesWindow(bAtTrainer)
	if bAtTrainer then
		return -- There is other dedicated UI for ability buying from a trainer
	end

	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsShown() then
		self:OnClose()
	else
		self:BuildWindow()
	end

	if GameLib.GetPlayerUnit() then
		self:OnCharacterCreated()
	end
end

function Abilities:BuildWindow()
	if not self.wndMain or not self.wndMain:IsValid() then
		local nNumSpecs = AbilityBook.GetNumUnlockedSpecs()

		self.wndMain = Apollo.LoadForm(self.xmlDoc, "AbilitiesBuilderForm", nil, self)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("InterfaceMenu_AbilityBuilder")})

		local wndBGFrame = self.wndMain:FindChild("BGFrame")
		local wndAbilityBuilder = wndBGFrame:FindChild("AbilityBuilderMain")
		local wndBottomContainer = wndAbilityBuilder:FindChild("BottomContainer")
		local wndSpellFilterTabs = wndAbilityBuilder:FindChild("SpellFilterTabContainer")

		self.wndGadgetSlot = wndBottomContainer:FindChild("HiddenGadgetSlot")
		self.wndPathSlot = wndBottomContainer:FindChild("CurrentSetPath:PathSlotItem")
		self.wndPathTabBtn = wndSpellFilterTabs:FindChild("SpellFilterTab_Path")

		wndBGFrame:FindChild("ErrorContainer"):Show(false, true)
		self.wndMain:FindChild("LeaveConfirmationContainer"):Show(false, true)
		self.wndMain:SetSizingMaximum(1600, 975)

		local wndTopContainer = wndBGFrame:FindChild("BGTopContainer")
		wndTopContainer:FindChild("AbilityBuilderTabBtn"):AttachWindow(wndAbilityBuilder)
		wndTopContainer:FindChild("AMPTabBtn"):AttachWindow(wndBGFrame:FindChild("AMPBuilderMain"))

		local wndTitleSet = self.wndMain:FindChild("BGPointsContainer:BGTitleSet")
		wndTitleSet:FindChild("SetLeftBtn"):Enable(nNumSpecs > 1)
		wndTitleSet:FindChild("SetRightBtn"):Enable(nNumSpecs > 1)

		local wndSpellFilterTabs = wndAbilityBuilder:FindChild("SpellFilterTabContainer")
		wndSpellFilterTabs:FindChild("SpellFilterTab_Assault"):SetCheck(true)
		wndSpellFilterTabs:FindChild("SpellFilterTab_Assault"):SetData(Spell.CodeEnumSpellTag.Assault)
		wndSpellFilterTabs:FindChild("SpellFilterTab_Support"):SetData(Spell.CodeEnumSpellTag.Support)
		wndSpellFilterTabs:FindChild("SpellFilterTab_Utility"):SetData(Spell.CodeEnumSpellTag.Utility)
		wndSpellFilterTabs:FindChild("SpellFilterTab_Path"):SetData(Spell.CodeEnumSpellTag.Path)

		self.bDirtyBit = false
		self.tCurrentDragData = false

		if self.locSavedLocation then
			self.wndMain:MoveToLocation(self.locSavedLocation)
		end
	end

	self.wndMain:Invoke()
	self:RedrawFromScratch()
	Event_FireGenericEvent("AbilityWindowHasBeenToggled")
	Event_FireGenericEvent("ToggleBlockBarsVisibility", true)
	Event_ShowTutorial(GameLib.CodeEnumTutorial.AbilityWindow)
end

function Abilities:OnCharacterCreated()
	self:RedrawFromScratch()
end

function Abilities:OnWindowClosed(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	if self.bDirtyBit and not self.wndMain:FindChild("LeaveConfirmationContainer"):IsShown() then
		self.wndMain:FindChild("LeaveConfirmationContainer"):Invoke()
		self.wndMain:Invoke() -- Reshow
	else
		self:OnCloseFinal()
	end
end

function Abilities:OnClose()
	if self.bDirtyBit and not self.wndMain:FindChild("LeaveConfirmationContainer"):IsShown() then
		self.wndMain:FindChild("LeaveConfirmationContainer"):Invoke()
	else
		self:OnCloseFinal()
	end
end

function Abilities:OnCloseFinal() -- Window Escape Key also routes here
	if self.wndMain then
		self.locSavedLocation = self.wndMain:GetLocation()
		self.wndMain:Close()
		self.wndMain:Destroy()
		AbilityBook.ClearCachedLASUpdates()
		AbilityBook.ClearCachedEldanAugmentationSpec() -- If we fully exit, undo changes
	end

	Event_FireGenericEvent("ToggleBlockBarsVisibility", false) -- TODO: Remove this, you can click close with a drag to circumvent the soft gate
	self:UpdateInterfaceMenuAlerts()
end

function Abilities:OnRedrawFromUI()
	self:DrawSpellBook()
end

function Abilities:OnSetResetClick(wndHandler, wndControl)
	AbilityBook.ClearCachedLASUpdates()
	AbilityBook.ClearCachedEldanAugmentationSpec()
	self:RedrawFromScratch()
	Event_FireGenericEvent("GenericEvent_OpenEldanAugmentation", self.wndMain:FindChild("BGFrame:AMPBuilderMain"))
end

function Abilities:OnSetActivateClick(wndHandler, wndControl)
	local wndContainer = self.wndMain:FindChild("BGFrame:AbilityBuilderMain:BottomContainer:CurrentSetSlots:SlotItemContainer")
	if not wndContainer:GetChildren() then
		return
	end

	self.bDirtyBit = false

	-- Commit AMPs to get relevant buffs and such
	--AbilityBook.CommitEldanAugmentationSpec()

	-- Now abilities
	local arSpellIds = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	for idx, wndCurr in pairs(wndContainer:GetChildren()) do
		arSpellIds[idx] = wndCurr:FindChild("SlotDisplay"):GetAbilityId()
	end
	arSpellIds[9] = self.wndGadgetSlot:FindChild("GadgetSlotItem:SlotDisplay"):GetAbilityId()
	arSpellIds[10] = self.wndPathSlot:FindChild("SlotDisplay"):GetAbilityId()

	local tResultInfo = ActionSetLib.RequestActionSetChanges(arSpellIds)
	if tResultInfo.eResult == ActionSetLib.CodeEnumLimitedActionSetResult.RestrictedInPVP or tResultInfo.eResult == ActionSetLib.CodeEnumLimitedActionSetResult.InCombat then
		self:HelperShowError(Apollo.GetString("AbilityBuilder_BuildsCantBeChangedCombat"))
		return
	elseif tResultInfo.eResult ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok then
		self:HelperShowError(Apollo.GetString("AbilityBuilder_InvalidSetWarning"))

		if tResultInfo.eResult == ActionSetLib.CodeEnumLimitedActionSetResult.MissingTag then
			for idx, strTag in pairs(tResultInfo.tTags) do
				self:HelperShowError(Apollo.GetString("AbilityBuilder_InvalidSetWarning"))
			end
		end
		return
	end

	self:OnCloseFinal() -- TODO: Optional, way want to take this out
end

-----------------------------------------------------------------------------------------------
-- Main Draw Methods
-----------------------------------------------------------------------------------------------

function Abilities:RedrawFromScratch() -- Draw Slots destroys everything (Level up and keybind change also routes here)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local wndSlotItemContainer = self.wndMain:FindChild("BGFrame:AbilityBuilderMain:BottomContainer:CurrentSetSlots:SlotItemContainer")
	wndSlotItemContainer:DestroyChildren()
	for idx = 1, 8 do
		local wndCurrSlot = Apollo.LoadForm(self.xmlDoc, "SlotItem", wndSlotItemContainer, self)
		local wndSlotBlocker = wndCurrSlot:FindChild("SlotLockedBlocker")
		wndCurrSlot:SetData(idx)
		wndCurrSlot:FindChild("SlotDisplay"):SetAbilityId(0)
		wndCurrSlot:FindChild("SlotMouseCatcher"):SetData(wndCurrSlot)
		wndCurrSlot:FindChild("SlotCloseBtn"):SetData(wndCurrSlot:FindChild("SlotDisplay"))
		wndSlotBlocker:SetTooltip(Apollo.GetString("AbilityBuilder_SlotLockedTooltip"))
		wndSlotBlocker:Show(ActionSetLib.IsSlotUnlocked(idx - 1) ~= ActionSetLib.CodeEnumLimitedActionSetResult.Ok) -- GOTCHA Lua indexs at 1, Code indexs at 0
		wndCurrSlot:FindChild("SlotText"):SetText(GameLib.GetKeyBinding("LimitedActionSet"..idx) or idx) -- Reliance on exact string names
	end
	wndSlotItemContainer:ArrangeChildrenHorz(0)
	self.wndPathSlot:FindChild("SlotText"):SetText(GameLib.GetKeyBinding("CastPathAbility"))

	-- drawing from scratch, we should grab the current saved action bar set
	local tActionSetIds = ActionSetLib.GetCurrentActionSet()
	if tActionSetIds == nil then
		return
	end

	for idx, nAbilityId in pairs(tActionSetIds) do
		if idx == 9 then
			self.wndGadgetSlot:FindChild("GadgetSlotItem:SlotDisplay"):SetAbilityId(nAbilityId)
		elseif idx == 10 then
			self.wndPathSlot:FindChild("SlotDisplay"):SetAbilityId(nAbilityId)
		else
			local wndSlot = wndSlotItemContainer:GetChildren()[idx]
			if wndSlot then
				local wndDisplay = wndSlot:FindChild("SlotDisplay")
				wndDisplay:SetAbilityId(nAbilityId)
			end
		end
	end

	-- Update rest
	self.bDirtyBit = false
	self:DrawSpellBook()
end

function Abilities:OnAbilitiesTabCheck(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_CloseEldanAugmentation")
	self.wndMain:FindChild("BGPointsContainer:AbilityHighlight"):Show(true)
	self.wndMain:FindChild("BGPointsContainer:AMPHighlight"):Show(false)
end

function Abilities:OnAmpTabCheck(wndHandler, wndControl)
	Event_FireGenericEvent("GenericEvent_OpenEldanAugmentation", self.wndMain:FindChild("BGFrame:AMPBuilderMain"))
	self.wndMain:FindChild("BGPointsContainer:AbilityHighlight"):Show(false)
	self.wndMain:FindChild("BGPointsContainer:AMPHighlight"):Show(true)
end

function Abilities:DrawSpellBook()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then
		return
	end

	-- Ability Points
	local bCheckPlayerRealLevel = true
	local nPlayerLevel = GameLib.GetPlayerLevel(bCheckPlayerRealLevel)
	local nAbilityPoints = GameLib.GetAbilityPoints()
	local nTotalAbilityPoints = GameLib.GetTotalAbilityPoints()

	local wndBGPointsContainer = self.wndMain:FindChild("BGPointsContainer")
	local wndSpellbookAbilityPoints = wndBGPointsContainer:FindChild("SpellbookAbilityPointsBG")
	wndSpellbookAbilityPoints:FindChild("SpellbookAbilityPointsTextSmall"):SetText(String_GetWeaselString(Apollo.GetString("AbilitiesBuilder_AvailablePoints"), nTotalAbilityPoints))
	wndSpellbookAbilityPoints:FindChild("SpellbookAbilityPointsTextBig"):SetText(nAbilityPoints)
	wndSpellbookAbilityPoints:FindChild("SpellbookAbilityPointsTextBig"):SetTextColor(nAbilityPoints == 0 and ApolloColor.new("ff56b381") or ApolloColor.new("UI_WindowTitleYellow")) -- TODO HEX
	wndSpellbookAbilityPoints:FindChild("SpellbookAbilityPointsReset"):Enable(nAbilityPoints ~= nTotalAbilityPoints)

	-- AMP Points
	self:HelperRedrawPoints()

	-- Spell Filter Tabs
	local eSelectedFilter = nil
	for idx, wndCurr in pairs(self.wndMain:FindChild("BGFrame:AbilityBuilderMain:SpellFilterTabContainer"):GetChildren()) do
		wndCurr:FindChild("SpellFilterTabName"):SetTextColor(wndCurr:IsChecked() and "ff31fcf6" or "ff2f94ac")
		if wndCurr:IsChecked() then
			eSelectedFilter = wndCurr:GetData() -- e.g. SpellFilterTab_Assault with data Spell.CodeEnumSpellTag.Assault
			break
		end
	end

	-- Determine Base ability and the HighestTier ability
	local tActiveAbilityList = {}
	local tNotActiveAbilityList = {}
	local tAllAbilities = AbilityBook.GetAbilitiesList(eSelectedFilter) or {}
	for idx, tBaseAbility in pairs(tAllAbilities) do
		local tHighestTier = tBaseAbility.tTiers[1] -- assume the first tier is the highest tier
		if tBaseAbility.bIsActive then
			tHighestTier = tBaseAbility.tTiers[tBaseAbility.nCurrentTier]
			table.insert(tActiveAbilityList, { tBaseAbility, tHighestTier })
		else
			table.insert(tNotActiveAbilityList, tHighestTier)
		end
	end
	table.sort(tActiveAbilityList, function(a,b) return (self:HelperSortLevelReqThenID(a[1].tTiers[1], b[1].tTiers[1])) end)
	table.sort(tNotActiveAbilityList, function(a,b) return (self:HelperSortLevelReqThenID(a,b)) end)

	-- refreshing the screen should always use the temp storage until the new set is commited
	-- TODO REFACTOR
	local arSpellIds = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	for idx, wndCurr in pairs(self.wndMain:FindChild("BGFrame:AbilityBuilderMain:BottomContainer:CurrentSetSlots:SlotItemContainer"):GetChildren()) do
		arSpellIds[idx] = wndCurr:FindChild("SlotDisplay"):GetAbilityId()
	end
	arSpellIds[9] = self.wndGadgetSlot:FindChild("GadgetSlotItem:SlotDisplay"):GetAbilityId()
	arSpellIds[10] = self.wndPathSlot:FindChild("SlotDisplay"):GetAbilityId()

	-- Build active abilities
	local wndSpellbook = self.wndMain:FindChild("BGFrame:AbilityBuilderMain:SpellbookContainer")
	local nVScrollPos = wndSpellbook:GetVScrollPos()
	wndSpellbook:DestroyChildren()

	for idx, tTable in pairs(tActiveAbilityList) do
		local tBaseAbility = tTable[1]
		local tHighestTier = tTable[2]
		local bOnMyBar = false
		for idx2, nAbilityId in pairs(arSpellIds) do
			if nAbilityId == tHighestTier.nId then
				bOnMyBar = true
				break
			end
		end

		if bOnMyBar then
			self:DrawATiersSpell(tBaseAbility, tHighestTier, nPlayerLevel, nAbilityPoints)
		else
			self:DrawAnAddSpell(tBaseAbility, tHighestTier)
		end
	end

	-- Build inactive abilities last
	for idx, tHighestTier in ipairs(tNotActiveAbilityList) do
		self:DrawALockedSpell(tHighestTier, nPlayerLevel)
	end

	wndSpellbook:ArrangeChildrenVert(0)
	wndSpellbook:SetVScrollPos(nVScrollPos)

	-- Set Title
	local strSetTitle = String_GetWeaselString(Apollo.GetString("AbilityBuilder_ActionSetLabel"), AbilityBook.GetCurrentSpec() or 1)
	self.wndMain:FindChild("BGPointsContainer:BGTitleSet:SetName"):SetText(self.bDirtyBit and strSetTitle.."*" or strSetTitle)
end

function Abilities:DrawALockedSpell(tHighestTier, nPlayerLevel)
	local wndCurrSpell = self:FactoryProduce(self.wndMain:FindChild("BGFrame:AbilityBuilderMain:SpellbookContainer"), "SpellbookItem_Locked", tHighestTier)
	local wndSpellbookItem = wndCurrSpell:FindChild("SpellbookItemBG")
	wndSpellbookItem:FindChild("SpellbookItemName"):SetText(tHighestTier.strName or "???")
	wndSpellbookItem:FindChild("SpellbookItemAbilityIcon"):SetAbilityId(tHighestTier.nId)

	-- Can assume not Active
	local strSubText = ""
	local bPurchaseThis = false
	local nAbilityLevelReq = tHighestTier.nLevelReq or 0
	if self.wndPathTabBtn:IsChecked() then
		strSubText = String_GetWeaselString(Apollo.GetString("AbilityBuilder_PathUnlock"), nAbilityLevelReq)
	elseif tHighestTier.bAMPUnlocked then
		strSubText = Apollo.GetString("AbilityBuilder_AMPUnlock")
	elseif nAbilityLevelReq > (nPlayerLevel or 0) then
		strSubText = String_GetWeaselString(Apollo.GetString("AbilityBuilder_LevelUnlock"), nAbilityLevelReq)
	else
		strSubText = Apollo.GetString("AbilityBuilder_PurchaseUnlock")
		bPurchaseThis = true
	end
	wndSpellbookItem:FindChild("SpellbookItemBG:SpellbookItemSubtext"):SetText(strSubText)

	-- Buy
	if bPurchaseThis then
		local bCanAfford = tHighestTier.nTrainingCost <= GameLib.GetPlayerCurrency():GetAmount()
		wndSpellbookItem:FindChild("BuyAbilityCost"):Show(true)
		wndSpellbookItem:FindChild("BuyAbilityCost"):SetAmount(tHighestTier.nTrainingCost, true)
		wndSpellbookItem:FindChild("BuyAbilityCost"):SetTextColor(bCanAfford and ApolloColor.new("white") or ApolloColor.new("UI_WindowTextRed"))
		wndSpellbookItem:FindChild("BuyAbilityBtn"):Show(true)
		wndSpellbookItem:FindChild("BuyAbilityBtn"):Enable(bCanAfford)
		wndSpellbookItem:FindChild("BuyAbilityBtn"):SetData(tHighestTier.nId) -- For OnBuyAbilityBtn
	end
end

function Abilities:OnBuyAbilityBtn(wndHandler, wndControl)
	AbilityBook.ActivateSpell(wndHandler:GetData(), true)
	Sound.Play(Sound.PlayUIUnlockAbility)
	--self:RedrawFromScratch()
end

function Abilities:DrawAnAddSpell(tBaseAbility, tHighestTier)
	local wndCurrSpell = self:FactoryProduce(self.wndMain:FindChild("BGFrame:AbilityBuilderMain:SpellbookContainer"), "SpellbookItem_Add", tHighestTier)
	local wndSpellbookItem = wndCurrSpell:FindChild("SpellbookItemBG")
	wndSpellbookItem:FindChild("SpellbookItemAdd"):SetData(tHighestTier)
	wndSpellbookItem:FindChild("SpellbookItemName"):SetText(tHighestTier.strName or "???")
	wndSpellbookItem:FindChild("SpellbookItemAbilityIcon"):SetAbilityId(tHighestTier.nId)
end

function Abilities:DrawATiersSpell(tBaseAbility, tHighestTier, nPlayerLevel, nAbilityPoints)
	local wndCurrSpell = self:FactoryProduce(self.wndMain:FindChild("BGFrame:AbilityBuilderMain:SpellbookContainer"), "SpellbookItem_Tiers", tHighestTier)
	local wndSpellbookItem = wndCurrSpell:FindChild("SpellbookItemBG")
	wndSpellbookItem:FindChild("SpellbookItemSubBtn"):SetData(tHighestTier)
	wndSpellbookItem:FindChild("SpellbookItemName"):SetText(tHighestTier.strName or "???")
	wndSpellbookItem:FindChild("SpellbookItemAbilityIcon"):SetAbilityId(tHighestTier.nId)

	-- Path won't show tiers
	local wndSpellbookProgPiecesContainer = wndSpellbookItem:FindChild("SpellbookItemProgPiecesContainer")
	wndSpellbookProgPiecesContainer:Show(not self.wndPathTabBtn:IsChecked())
	wndSpellbookItem:FindChild("SpellbookItemName"):Show(self.wndPathTabBtn:IsChecked())


	if not self.wndPathTabBtn:IsChecked() then
		-- Prog Pieces
		wndSpellbookProgPiecesContainer:DestroyChildren()
		local nStart = 0
		for idx, tBtnTier in pairs(tBaseAbility.tTiers or {}) do
			local bLevelReq = nPlayerLevel >= tBtnTier.nLevelReq
			local bPointsReq = tBtnTier.bIsActive or nAbilityPoints > 0
			local strFormName = (idx == 1) and "SpellbookProgPieceFirst" or (idx == 5) and "SpellbookProgPieceBig" or (idx == 9 and "SpellbookProgPieceBigEnd") or "SpellbookProgPiece"
			local wndProgPiece = Apollo.LoadForm(self.xmlDoc, strFormName, wndSpellbookProgPiecesContainer, self)
			wndProgPiece:SetData(tBtnTier.splObject) -- For tooltip (OnSpellbookProgPieceTooltip)

			-- Button
			local wndProgPieceBtn = wndProgPiece:FindChild("SpellbookProgPieceBtn")
			wndProgPieceBtn:SetData(tBtnTier)
			wndProgPieceBtn:SetCheck(tBtnTier.bIsActive)
			wndProgPieceBtn:Enable(bLevelReq and bPointsReq)
			wndProgPieceBtn:SetText(idx == 1 and Apollo.GetString("Tooltips_Base") or "")

			-- Tooltip is on parent and not the button as it may disable
			if not bLevelReq then
				wndProgPiece:SetTooltip(String_GetWeaselString(Apollo.GetString("AbilityBuilder_TierUnlockLevel"), tBtnTier.nLevelReq))
			elseif not bPointsReq then
				wndProgPiece:SetTooltip(Apollo.GetString("AbilityBuilder_OutOfPoints"))
			end

			local nLeft, nTop, nRight, nBottom = wndProgPiece:GetAnchorOffsets()
			local nWidth = idx == 5 and 214 or idx == 9 and 250 or 102


			wndProgPiece:SetAnchorOffsets(nStart, nTop, nStart + nWidth, nBottom)
			nStart = nStart + nWidth - 50
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Spellbook Events (Dirty Bit Events)
-----------------------------------------------------------------------------------------------

function Abilities:OnSpellbookItemAdd(wndHandler, wndControl)
	self.bDirtyBit = true
	local tCurrAbility = wndHandler:GetData()
	if self.wndPathTabBtn:IsChecked() then
		self.wndPathSlot:FindChild("SlotDisplay"):SetAbilityId(tCurrAbility.nId)
	else
		self:HelperAddSlot(tCurrAbility.nId)
	end
	self:DrawSpellBook()
end

function Abilities:OnSpellbookItemSubBtn(wndHandler, wndControl)
	self.bDirtyBit = true
	local tCurrAbility = wndHandler:GetData()
	if self.wndPathTabBtn:IsChecked() then
		self:HelperDeleteSlot(self.wndMain:FindChild("BGFrame:AbilityBuilderMain:BottomContainer:CurrentSetPath:PathSlotItem:SlotDisplay"), true)
	else
		for idx, wndCurr in pairs(self.wndMain:FindChild("BGFrame:AbilityBuilderMain:BottomContainer:CurrentSetSlots:SlotItemContainer"):GetChildren()) do
			-- Find the window to remove
			if wndCurr:FindChild("SlotDisplay"):GetAbilityId() == tCurrAbility.nId then
				self:HelperDeleteSlot(wndCurr:FindChild("SlotDisplay"), true)
				break
			end
		end
	end
	self:DrawSpellBook()
end

function Abilities:OnSpellbookProgPieceToggle(wndHandler, wndControl) -- SpellbookProgPieceBtn
	self.bDirtyBit = true
	AbilityBook.UpdateSpellTier(wndHandler:GetData().nId, wndHandler:GetData().nTier)
	self:DrawSpellBook()
end

function Abilities:OnSpellbookAbilityPointsReset(wndHandler, wndControl) -- SpellbookAbilityPointsReset
	self.bDirtyBit = true
	for idx, wndCurr in pairs(self.wndMain:FindChild("BGFrame:AbilityBuilderMain:BottomContainer:CurrentSetSlots:SlotItemContainer"):GetChildren()) do -- Reset all to 1
		AbilityBook.UpdateSpellTier(wndCurr:FindChild("SlotDisplay"):GetAbilityId(), 1)
	end
	self:DrawSpellBook()
end

function Abilities:OnCurrentSetSlotsClearAll(wndHandler, wndControl)
	self.bDirtyBit = true
	local wndBottomContainer = self.wndMain:FindChild("BGFrame:AbilityBuilderMain:BottomContainer")
	for idx, wndCurr in pairs(wndBottomContainer:FindChild("CurrentSetSlots:SlotItemContainer"):GetChildren()) do -- Find the window to remove
		local wndSlot = wndCurr:FindChild("SlotDisplay")
		if wndSlot:GetAbilityId() ~= 0 then
			self:HelperDeleteSlot(wndSlot, true)
		end
	end

	local wndPathSlot = wndBottomContainer:FindChild("CurrentSetPath:PathSlotItem:SlotDisplay")
	if wndPathSlot:GetAbilityId() ~= 0 then
		self:HelperDeleteSlot(wndPathSlot, true)
	end

	self:DrawSpellBook()
end

function Abilities:OnToggleDirtyBit(bNewValue)
	self.bDirtyBit = bNewValue
	self:HelperRedrawPoints()
end

-----------------------------------------------------------------------------------------------
-- Bottom Action Bar Events (DirtyBit Events)
-----------------------------------------------------------------------------------------------

function Abilities:SlotItemMouseEnter(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:FindChild("SlotCloseBtn") and wndHandler:FindChild("SlotDisplay") then
		wndHandler:FindChild("SlotCloseBtn"):Show(wndHandler:FindChild("SlotDisplay"):GetAbilityId() ~= 0)
	end
end

function Abilities:SlotItemMouseExit(wndHandler, wndControl)
	if wndHandler == wndControl and wndHandler:FindChild("SlotCloseBtn") then
		wndHandler:FindChild("SlotCloseBtn"):Show(false)
	end
end

function Abilities:OnSlotMouseDown(wndHandler, wndControl, eMouseButton, nPosX, nPosY, bDoubleClick)
	if wndHandler ~= wndControl then -- wndHandler is SlotMouseCatcher and the data is the "SlotDisplay" window
		return
	end

	if (eMouseButton == GameLib.CodeEnumInputMouse.Left and bDoubleClick) or eMouseButton == GameLib.CodeEnumInputMouse.Right then
		self.bDirtyBit = true
		if self.wndPathSlot:FindChild("SlotMouseCatcher") == wndHandler then
			self.wndPathSlot:FindChild("SlotCloseBtn"):Show(false)
			self.wndPathSlot:FindChild("SlotDisplay"):SetAbilityId(0)
			self:DrawSpellBook()
			-- TODO: Perhaps detect gadget and equip/unequip, or offer a picker
		else
			local wndSlotItem = wndHandler:GetData()
			wndSlotItem:FindChild("SlotCloseBtn"):Show(false)
			self:HelperDeleteSlot(wndSlotItem:FindChild("SlotDisplay"))
		end
		return true -- TODO SECURITY This soft gates right click spell casting from your book. Easily circumvented.
	end
end

function Abilities:OnSlotCloseBtnClick(wndHandler, wndControl)
	if wndHandler ~= wndControl then -- wndHandler is "SlotCloseBtn" and the data is the "SlotDisplay" window
		return
	end

	self.bDirtyBit = true

	if self.wndPathSlot:FindChild("SlotCloseBtn") == wndHandler then
		self:HelperDeleteSlot(self.wndPathSlot:FindChild("SlotDisplay"))
	else
		self:HelperDeleteSlot(wndHandler:GetData(), true)
	end

	wndHandler:Show(false)
	self:DrawSpellBook()
end

-----------------------------------------------------------------------------------------------
-- Bottom Action Bar Events (Drag Drop)
-----------------------------------------------------------------------------------------------

function Abilities:OnStartDragSkillFromSlots(wndHandler, wndControl)
	if not wndHandler or self.tCurrentDragData then -- wndHandler should be "SlotDisplay"
		return -- Early exit if already dragging, this can occur if moving the mouse from spellbook over a slot item
	end

	self.tCurrentDragData = { wndHandler, wndHandler:GetAbilityId() } -- We need the table since we delete right away
	wndHandler:SetAbilityId(0) -- Not using HelperDeleteSlot as we don't want to reset points
	self:DrawSpellBook()
end

function Abilities:OnQueryDragSkillOverSlotItem(wndHandler, wndControl)
	return Apollo.DragDropQueryResult.Accept -- This event is on the Slot (not the Spellbook) so always accept
end

function Abilities:OnEndDragSkillOntoSlotItem(wndHandler, wndControl)
	if not wndHandler or not self.tCurrentDragData then -- wndHandler should be the target "SlotItem"
		return
	end

	-- Save then Swap
	local idSwapAbility = wndHandler:FindChild("SlotDisplay"):GetAbilityId()
	wndHandler:FindChild("SlotDisplay"):SetAbilityId(self.tCurrentDragData[2])

	if idSwapAbility ~= 0 then
		self.tCurrentDragData[1]:SetAbilityId(idSwapAbility)
	end

	self.tCurrentDragData = false

	self:DrawSpellBook()
end

-----------------------------------------------------------------------------------------------
-- Errors
-----------------------------------------------------------------------------------------------

function Abilities:HelperShowError(strMessage)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	local wndError = self.wndMain:FindChild("BGFrame:ErrorContainer")
	wndError:Show(true)
	wndError:FindChild("ErrorContainerMiddleBG:ErrorContainerText"):SetText(strMessage)
	Apollo.CreateTimer("AbilitiesBuilder_HideErrorContainerTimer", 3, false)
end

function Abilities:OnErrorContainerHideBtn()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	Apollo.StopTimer("AbilitiesBuilder_HideErrorContainerTimer")
	self.wndMain:FindChild("BGFrame:ErrorContainer"):Show(false)
end

function Abilities:OnLeaveConfirmationNo()
	self.wndMain:FindChild("LeaveConfirmationContainer"):Show(false)
end

function Abilities:OnLeaveConfirmationYes()
	self.wndMain:FindChild("LeaveConfirmationContainer"):Show(false)
	self:OnCloseFinal()
end

-----------------------------------------------------------------------------------------------
-- Sets
-----------------------------------------------------------------------------------------------

function Abilities:OnSetLeftBtn(wndHandler, wndControl)
	AbilityBook.PrevSpec()
end

function Abilities:OnSetRightBtn(wndHandler, wndControl)
	AbilityBook.NextSpec()
end

function Abilities:OnSpecChanged(newSpecIndex, specError)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	if specError == AbilityBook.CodeEnumSpecError.InvalidIndex then
		self:HelperShowError(Apollo.GetString("AbilityBuilder_SetIndexOutOfBounds"))
	elseif specError == AbilityBook.CodeEnumSpecError.IndexLocked then
		self:HelperShowError(Apollo.GetString("AbilityBuilder_SetIndexLocked"))
	elseif specError == AbilityBook.CodeEnumSpecError.NoChange then
		self:HelperShowError(Apollo.GetString("AbilityBuilder_SetIndexNotChanged"))
	elseif specError == AbilityBook.CodeEnumSpecError.InCombat then
		self:HelperShowError(Apollo.GetString("AbilityBuilder_SetChangeInCombat"))
	elseif specError == AbilityBook.CodeEnumSpecError.InvalidPlayer then
		self:HelperShowError(Apollo.GetString("AbilityBuilder_SetChangeInvalidPlayer"))
	elseif specError == AbilityBook.CodeEnumSpecError.PvPRestricted then
		self:HelperShowError(Apollo.GetString("AbilityBuilder_SetChangeInPvP"))
	elseif specError == AbilityBook.CodeEnumSpecError.InVoid then
		self:HelperShowError(Apollo.GetString("AbilityBuilder_SetChangeInVoid"))
	elseif specError == AbilityBook.CodeEnumSpecError.Ok then
		self:RedrawFromScratch()
		Event_FireGenericEvent("GenericEvent_OpenEldanAugmentation", self.wndMain:FindChild("BGFrame:AMPBuilderMain"))
	end
end

function Abilities:OnActionSetError(eResult)
	local strMessage = nil	
	if eResult == ActionSetLib.CodeEnumLimitedActionSetResult.InVoid then
		strMessage = Apollo.GetString("ActionSet_Error_InTheVoid")
		-- TODO MORE
	end

	if strMessage then		
		self:BuildWindow() -- This can happen after the set has "successfully" closed, so bring it back up if closed
		self:HelperShowError(strMessage)
	end
end

-----------------------------------------------------------------------------------------------
-- Level Up Unlock System
-----------------------------------------------------------------------------------------------

function Abilities:OnLevelUpUnlock_TierPointSystem()
	self:BuildWindow()

	local wndAbilityBuilderTabBtn = self.wndMain:FindChild("BGFrame:BGTopContainer:AbilityBuilderTabBtn")
	wndAbilityBuilderTabBtn:SetCheck(true)
	self:OnAbilitiesTabCheck(wndAbilityBuilderTabBtn, wndAbilityBuilderTabBtn)
	self.wndMain:FindChild("BGFrame:BGTopContainer:AMPTabBtn"):SetCheck(false)
end

function Abilities:OnLevelUpUnlock_AMPSystem()
	self:BuildWindow()

	local wndAMPTabBtn = self.wndMain:FindChild("BGFrame:BGTopContainer:AMPTabBtn")
	wndAMPTabBtn:SetCheck(true)
	self:OnAmpTabCheck(wndAMPTabBtn, wndAMPTabBtn)
	self.wndMain:FindChild("BGFrame:BGTopContainer:AbilityBuilderTabBtn"):SetCheck(false)
end

function Abilities:OnLevelUpUnlock_Class_Ability(splAbility)
	self:OnLevelUpUnlock_TierPointSystem()
end

function Abilities:OnLevelUpUnlock_Path_Spell(splAbility)
	self:OnLevelUpUnlock_TierPointSystem()
end

---------------------------------------------------------------------------------------------------
-- Tutorial anchor request
---------------------------------------------------------------------------------------------------

function Abilities:OnTutorial_RequestUIAnchor(eAnchor, idTutorial, strPopupText)
	if eAnchor ~= GameLib.CodeEnumTutorialAnchor.Abilities then return end

	local tRect = {}
	tRect.l, tRect.t, tRect.r, tRect.b = self.wndMain:GetRect()

	Event_FireGenericEvent("Tutorial_RequestUIAnchorResponse", eAnchor, idTutorial, strPopupText, tRect)
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function Abilities:HelperRedrawPoints()
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local nTotalAMP = AbilityBook.GetTotalPower()
	local nAvailableAMP = AbilityBook.GetAvailablePower()
	local wndBGPointsContainer = self.wndMain:FindChild("BGPointsContainer")
	wndBGPointsContainer:FindChild("AMPPoints:AMPPointsTextSmall"):SetText(String_GetWeaselString(Apollo.GetString("AbilitiesBuilder_AvailablePoints"), nTotalAMP))
	wndBGPointsContainer:FindChild("AMPPoints:AMPPointsTextBig"):SetText(nAvailableAMP)
	wndBGPointsContainer:FindChild("AMPPoints:AMPPointsTextBig"):SetTextColor(nAvailableAMP == 0 and ApolloColor.new("ff56b381") or ApolloColor.new("UI_WindowTitleYellow")) -- TODO HEX

	self:UpdateInterfaceMenuAlerts()
end

function Abilities:HelperAddSlot(nAbilityId) -- Path Skills will use another method
	if nAbilityId == 0 then
		return
	end

	-- Try to put it into the first available empty slot
	local bEmptySlotFound = false
	local wndSlotItemContainer = self.wndMain:FindChild("BGFrame:AbilityBuilderMain:BottomContainer:CurrentSetSlots:SlotItemContainer")
	for idx, wndCurr in pairs(wndSlotItemContainer:GetChildren()) do
		local wndSlotDisplay = wndCurr:FindChild("SlotDisplay")
		if wndSlotDisplay:GetAbilityId() == 0 and not wndCurr:FindChild("SlotLockedBlocker"):IsShown() then
			bEmptySlotFound = true
			wndSlotDisplay:SetAbilityId(nAbilityId)
			break
		end
	end

	-- If full, we just slot it in the last position
	if not bEmptySlotFound then
		local nMaxSlots = 0
		for idx, wndCurr in pairs(wndSlotItemContainer:GetChildren()) do
			if wndCurr:FindChild("SlotDisplay") and not wndCurr:FindChild("SlotLockedBlocker"):IsShown() then
				nMaxSlots = nMaxSlots + 1
			end
		end

		local wndMaxSlot = wndSlotItemContainer:GetChildren()[nMaxSlots]
		if wndMaxSlot then
			local wndMaxDisplay = wndMaxSlot:FindChild("SlotDisplay")
			self:HelperDeleteSlot(wndMaxDisplay)
			wndMaxDisplay:SetAbilityId(nAbilityId)
		end
	end
end

function Abilities:HelperDeleteSlot(wndSlotDisplay, bSkipRedrawing)  -- Path Skills will use another method
	AbilityBook.UpdateSpellTier(wndSlotDisplay:GetAbilityId(), 1)
	wndSlotDisplay:SetAbilityId(0)
	wndSlotDisplay:SetTooltipForm(nil)
	if not bSkipRedrawing then
		self:DrawSpellBook()
	end
end

function Abilities:HelperFindNextTier(tCurrAbility)
	local nNextTier = tCurrAbility.nMaxTiers
	for idx, tTier in pairs(tCurrAbility.tTiers) do
		if not tTier.bIsActive then
			nNextTier = tTier.nTier
			break
		end
	end
	return nNextTier
end

function Abilities:OnGenerateTooltip(wndHandler, wndControl, tType, splTarget)
	if wndControl == wndHandler then
		if wndControl:GetAbilityTierId() and splTarget:GetId() ~= wndControl:GetAbilityTierId() then
			splTarget = GameLib.GetSpell(wndControl:GetAbilityTierId())
		end

		Tooltip.GetSpellTooltipForm(self, wndHandler, splTarget, {bTiers = not self.wndPathTabBtn:IsChecked()})
	end
end

function Abilities:OnSpellbookProgPieceTooltip(wndHandler, wndControl, tType, splTarget)
	Tooltip.GetSpellTooltipForm(self, wndHandler, wndHandler:GetData(), {bTiers = not self.wndPathTabBtn:IsChecked()})
end

function Abilities:HelperSortLevelReqThenID(a, b) -- Priority1: Level Req. Priority2: Ability ID.
	if a.nLevelReq == b.nLevelReq then
		return (a.nId or 0) < (b.nId or 0)
	else
		return (a.nLevelReq or 0) < (b.nLevelReq or 0)
	end
end

function Abilities:FactoryProduce(wndParent, strFormName, tObject)
	local wndNew = wndParent:FindChildByUserData(tObject)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndNew:SetData(tObject)
	end
	return wndNew
end

local AbilitiesInst = Abilities:new()
AbilitiesInst:Init()
