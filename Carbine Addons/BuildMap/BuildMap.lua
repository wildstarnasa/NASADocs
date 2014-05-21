-----------------------------------------------------------------------------------------------
-- Client Lua Script for BuildMap
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "DialogSys"
require "Quest"
require "MailSystemLib"
require "Sound"
require "GameLib"
require "Tooltip"
require "XmlDoc"
require "PlayerPathLib"
require "SettlerImprovement"
require "SoldierImprovement"

local BuildMap = {}

local ktAvenueTypeToString = 
{
	[0] = Apollo.GetString("BuildMap_Economy"),
	[1] = Apollo.GetString("BuildMap_Security"),
	[2] = Apollo.GetString("BuildMap_QOL"),
}

local ktAvenueTypeToColor = 
{
	[0] = ApolloColor.new("ff7fffb9"),
	[1] = ApolloColor.new("ffffb97f"),
	[2] = ApolloColor.new("ffb97fff"),
}

local knSaveVersion = 1

function BuildMap:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function BuildMap:Init()
    Apollo.RegisterAddon(self)
end

function BuildMap:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("BuildMap.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function BuildMap:OnDocumentReady()
	Apollo.RegisterEventHandler("CloseVendorWindow", 			"OnCloseBtn", self)
	Apollo.RegisterEventHandler("SettlerBuildResult", 			"OnCloseVendorWindow", self)
	Apollo.RegisterEventHandler("InvokeSettlerBuild", 			"OnInvokeSettlerBuild", self)
	Apollo.RegisterEventHandler("SettlerHubClose", 				"OnCloseBtn", self)
	Apollo.RegisterEventHandler("ChangeWorld", 					"OnCloseBtn", self)
	Apollo.RegisterEventHandler("SettlerHubUpdated", 			"OnSettlerHubUpdated", self)
	Apollo.RegisterEventHandler("SettlerBuildStatusUpdate", 	"OnSettlerBuildStatusUpdate", self)
	Apollo.RegisterEventHandler("ZoneMapPlayerIndicatorUpdated","OnPlayerIndicatorUpdated", self)

	-- TODO
	--Apollo.RegisterEventHandler("InvokeSoldierBuild", "OnInvokeSoldierBuild", self) -- TODO
	--Apollo.RegisterEventHandler("UpdateSoldierBuild", "OnUpdateSoldierBuild", self) -- TODO
	--Apollo.RegisterEventHandler("SoldierHoldoutStatus", "OnSoldierHoldoutStatus", self) -- TODO
end

function BuildMap:Initialize()
	if self.wndMain and self.wndMain:IsValid() then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "BuildMapForm", nil, self)
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	
	local wndWorldMap = self.wndMain:FindChild("TopSection:WorldMap")
	wndWorldMap:SetZone(GameLib.GetCurrentZoneMap().id)
	wndWorldMap:SetPlayerArrowSprite("sprMap_PlayerArrowBase")
	wndWorldMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Panning)
	wndWorldMap:CenterOnPlayer()
	self.wndMain:FindChild("BuilderMapFormBG:Settings:KeepWindowOpenBtn"):SetCheck(self.bKeepWindowOpen or false)

	if not self.eOverlayType then
		self.eOverlayType = wndWorldMap:CreateOverlayType()
	end
	self.nNumNodes = 0
	self.wndLastMouseEnter = nil
	self.wndExtraInfoScreen = nil
	self.ePlayerPathType = PlayerPathLib.GetPlayerPathType()
end

function BuildMap:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc

	local tSave = 
	{
		bKeepWindowOpen = self.bKeepWindowOpen,
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion
	}
	
	return tSave
end

function BuildMap:OnRestore(eType, tData)
	if not tData or tData.nSaveVersion ~= knSaveVersion or eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	self.bKeepWindowOpen = tData.bKeepWindowOpen or false
	
	if tData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tData.tWindowLocation)
	end
end

function BuildMap:OnInvokeSoldierBuild(unitPlayer, tList)
	-- TODO STUB
	--self:DrawSoldierOrSettlerProgressBars(tNodeForProgressBars)
	-- if SoldierEvent.is(tList) then tList = tList:GetImprovements() end
end

function BuildMap:DrawTierSoldier(solNode)
	-- TODO STUB
	--local wndNode = Apollo.LoadForm(self.xmlDoc, "SoldierBuildItem", self.wndMain:FindChild("ChoiceList"), self)
	--self:DrawSoldierBuildWindow(wndNode, tNode)
end

function BuildMap:OnSettlerBuildStatusUpdate(nHub, unitDepot)
	
end

function BuildMap:OnInvokeSettlerBuild(unitPlayer, tList)
	if not unitPlayer or not tList then
		return
	end

	self:Initialize()
	local wndWorldMap = self.wndMain:FindChild("TopSection:WorldMap")
	wndWorldMap:RemoveAllObjects()
	self.wndMain:FindChild("BottomSection:SelectionItemContainer"):DestroyChildren()
	self.wndMain:FindChild("BottomSection:CategoryFilterSection:CategoryFilterItemContainer"):DestroyChildren()
	wndWorldMap:SetData(tList)
	self:RedrawSelectionItems()
end

function BuildMap:RedrawSelectionItems()
	local tList = self.wndMain:FindChild("TopSection:WorldMap"):GetData() -- Passed in from InvokeBuild method
	if not tList then
		return
	end

	-----------------------------------------------------------------------------------------------
	-- Settler Categories (Note: Not destroyed in redraw)
	-----------------------------------------------------------------------------------------------
	local strIconPath = "sprMM_TargetObjective"
	local nArgAvenueType = nil
	if self.ePlayerPathType == PlayerPathLib.PlayerPathType_Settler then
		strIconPath = "PlayerPathContent_TEMP:spr_PathSet_MapIcon"
		local tCurrentHub = PlayerPathLib.GetSettlerHubValues(PlayerPathLib.GetCurrentSettlerHubMission())
		if tCurrentHub then
			self.wndMain:FindChild("BuilderMapFormBG:TopSectionTitleBG:TopSectionTitleText"):SetText(String_GetWeaselString(Apollo.GetString("BuildMap_Header"), PlayerPathLib.GetCurrentSettlerHubMission():GetName()))
			for nAvenueType, tCurrAvenue in ipairs(tCurrentHub.arAvenues) do
				if tCurrAvenue.nMax > 0 then
					local wndCategory = self:FactoryProduce(self.wndMain:FindChild("BottomSection:CategoryFilterSection:CategoryFilterItemContainer"), "CategoryFilterItem", tCurrAvenue.strName)
					local nPercent = math.floor(tCurrAvenue.nValue / tCurrAvenue.nMax * 100)
					local strCategoryProgress = String_GetWeaselString(Apollo.GetString("BuildMap_CategoryProgress"), tCurrAvenue.strName, tCurrAvenue.nValue, tCurrAvenue.nMax)
					local wndCategoryFilterName = wndCategory:FindChild("CategoryFilterBtn:CategoryFilterName")
					local wndCategoryFilterBar = wndCategory:FindChild("CategoryFilterBtn:CategoryFilterBar")
					wndCategoryFilterName:SetText(String_GetWeaselString(Apollo.GetString("BuildMap_Percent"), tCurrAvenue.strName, nPercent))
					wndCategoryFilterName:SetTextColor(ktAvenueTypeToColor[nAvenueType - 1])
					wndCategoryFilterBar:SetMax(tCurrAvenue.nMax)
					wndCategoryFilterBar:SetProgress(tCurrAvenue.nValue)
					wndCategory:SetTooltip(String_GetWeaselString(Apollo.GetString("BuildMap_Percent"), strCategoryProgress, nPercent))
					if wndCategory:FindChild("CategoryFilterBtn"):IsChecked() then
						nArgAvenueType = nAvenueType - 1
					end
				end
			end
		end
	elseif self.ePlayerPathType == PlayerPathLib.PlayerPathType_Soldier then
		strIconPath = "PlayerPathContent_TEMP:spr_PathSol_MapIcon"
	end
	self.wndMain:FindChild("BottomSection:CategoryFilterSection:CategoryFilterItemContainer"):ArrangeChildrenVert(0)

	-----------------------------------------------------------------------------------------------
	-- Selection Items
	-----------------------------------------------------------------------------------------------
	local tInfo =
	{
		strIcon = strIconPath,
		strIconEdge = strIconPath,
		crEdge = CColor.new(1, 1, 1, 1),
		crObject = CColor.new(1, 1, 1, 1),
	}

	self.nNumNodes = #tList
	for idx, tNode in ipairs(tList) do --if tNode:GetPosition() and tNode:GetName() then
		if SoldierImprovement.is(tNode) then
			self:DrawTierSoldier(tNode)
		elseif not nArgAvenueType or nArgAvenueType == tNode:GetAvenueType() then
			self:DrawTierSettler(tNode)
		end
		self.wndMain:FindChild("TopSection:WorldMap"):AddObject(self.eOverlayType, tNode:GetPosition(), tNode:GetName(), tInfo, {bNeverShowOnEdge = true, bFixedSizeLarge = true}, false, tNode)
	end

	if not self.wndExtraInfoScreen or not self.wndExtraInfoScreen:IsValid() or not self.wndExtraInfoScreen:IsShown() then
		self.wndMain:FindChild("BottomSection:SelectionItemContainer"):ArrangeChildrenHorz(0)
	end
end

function BuildMap:DrawTierSettler(setNode)
	local eAvenueType = setNode:GetAvenueType()
	for nTier, tCurrTier in ipairs(setNode:GetImprovements()) do
		if tCurrTier.idImprovement and not tCurrTier.bIsObsolete then
			local wndNode = self:FactoryProduce(self.wndMain:FindChild("BottomSection:SelectionItemContainer"), "SelectionItem", tCurrTier.idImprovement)

			local strName = setNode:GetName()
			if nTier > 1 then
				strName = String_GetWeaselString(Apollo.GetString("BuildMap_NameTier"), setNode:GetName(), nTier)
			end

			local strTooltip = string.format("<P Font=\"CRB_InterfaceMedium_O\">+%s %s</P>", setNode:GetContributionValue(nTier), ktAvenueTypeToString[eAvenueType])
			
			if tCurrTier.splDisplay and tCurrTier.splDisplay:GetFlavor() then
				strTooltip = string.format("<P Font=\"CRB_InterfaceMedium_O\">%s</P>%s", tCurrTier.splDisplay:GetFlavor(), strTooltip)
			end

			local strSprite = "Icon_Windows_UI_CRB_Colonist"
			if tCurrTier.splDisplay and tCurrTier.splDisplay:GetIcon() and string.len(tCurrTier.splDisplay:GetIcon()) > 0 then
				strSprite = tCurrTier.splDisplay:GetIcon()
			end

			local bHasMatsForAll = true
			if tCurrTier.arItems then
				for idx = 1, 3 do
					local tCurrItemData = tCurrTier.arItems[idx]
					if tCurrItemData and not tCurrItemData.bHasEnough then
						bHasMatsForAll = false
						break
					end
				end
			end

			local bPreReqNeeded = not tCurrTier.bIsActive and not tCurrTier.bCanPlace and tCurrTier.setRequiredOutpost
			local wndSelectionItemBtn = wndNode:FindChild("SelectionItemBtn")
			if tCurrTier.bIsActive then
				wndSelectionItemBtn:SetSprite("")
				wndSelectionItemBtn:ChangeArt("CRB_Basekit:kitBtn_List_MetalBorder")
			elseif tCurrTier.bCanPlace then
				wndSelectionItemBtn:SetSprite("")
				wndSelectionItemBtn:ChangeArt("CRB_Basekit:kitBtn_List_MetalBorder")
			elseif bPreReqNeeded then  -- Note: Obsolete is filtered out earlier
				wndSelectionItemBtn:SetSprite("CRB_Basekit:kitBtn_List_MetalBorder")
				wndSelectionItemBtn:ChangeArt("")
				wndSelectionItemBtn:FindChild("SelectionItemLock"):SetTooltip(String_GetWeaselString(Apollo.GetString("BuildMap_NeedsPrereq"), tCurrTier.setRequiredOutpost:GetName()))
			end

			local wndSelectionItemName = wndSelectionItemBtn:FindChild("SelectionItemName")
			wndSelectionItemName:SetText(strName)
			wndSelectionItemName:SetTextColor(ktAvenueTypeToColor[eAvenueType])
			local wndSelectionItemIcon = wndNode:FindChild("SelectionItemBtn:SelectionItemIcon")
			wndSelectionItemIcon:SetText("+"..setNode:GetContributionValue(nTier))
			wndSelectionItemIcon:SetTextColor(ktAvenueTypeToColor[eAvenueType])
			wndSelectionItemIcon:SetTooltip(strTooltip)
			wndSelectionItemIcon:SetSprite(strSprite)
			local wndSelectionItemCheckmark = wndSelectionItemBtn:FindChild("SelectionItemCheckmark")
			wndSelectionItemCheckmark:Show(tCurrTier.bIsActive)
			wndSelectionItemBtn:FindChild("SelectionItemNoMaterial"):Show(not bHasMatsForAll and not wndSelectionItemCheckmark:IsVisible())
			wndSelectionItemBtn:FindChild("SelectionItemLock"):Show(bPreReqNeeded)
			wndSelectionItemBtn:SetData({ setNode, nTier, tCurrTier, wndNode })
		end
	end
end

function BuildMap:OnCategoryFilterBtnCheck(wndHandler, wndControl)
	self.wndMain:FindChild("BottomSection:SelectionItemContainer"):DestroyChildren()
	self:HideMapHover()
	self:OnSettlerHubUpdated()
end

function BuildMap:OnCategoryFilterBtnUncheck(wndHandler, wndControl)
	for key, wndCurr in pairs(self.wndMain:FindChild("BottomSection:SelectionItemContainer"):GetChildren()) do
		if wndCurr and wndCurr:FindChild("SelectionItemBtn") then
			wndCurr:FindChild("SelectionItemBtn"):SetCheck(false)
		end
	end
	self:HideMapHover()
	self:OnSettlerHubUpdated()
end

function BuildMap:OnSettlerHubUpdated()
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsShown() then
		self:RedrawSelectionItems()
	end
end

function BuildMap:OnPlayerIndicatorUpdated()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsShown() then
		return
	end
	
	local wndWorldMap = self.wndMain:FindChild("TopSection:WorldMap")
	
	local tCurrentInfo = wndWorldMap:GetZoneInfo()
	if not tCurrentInfo then
		return
	end
	
	local signalLost = not wndWorldMap:IsShowPlayerOn()

	if tCurrentInfo.parentZoneId ~= 0 then
		signalLost = false
	end

	self.wndMain:FindChild("PlayerCursorHidden"):Show(signalLost)
end

-----------------------------------------------------------------------------------------------
-- Extra Info
-----------------------------------------------------------------------------------------------

function BuildMap:OnSelectionItemShowExtraInfo(wndHandler, wndControl) -- SelectionItemBtn, data is { tNode, nTier, tCurrTier, wndSelectionItem }
	if self.wndExtraInfoScreen then
		self.wndExtraInfoScreen:Destroy()
	end

	local tNodeInfo = wndHandler:GetData()
	
	local setNode = tNodeInfo[1]
	local nTier = tNodeInfo[2]
	local tCurrTier = tNodeInfo[3]
	local wndParent = tNodeInfo[4]
	local wndCurr = Apollo.LoadForm(self.xmlDoc, "SelectionItemPopOut", self.wndMain:FindChild("BottomSection:SelectionItemContainer"), self)
	wndCurr:SetData({ setNode, nTier, tCurrTier, wndParent })
	self.wndExtraInfoScreen = wndCurr

	if wndParent then
		local nLeft, nTop, nRight, nBottom = wndParent:GetAnchorOffsets()
		local nLeft2, nTop2, nRight2, nBottom2 = wndCurr:GetAnchorOffsets()
		wndCurr:SetAnchorOffsets(nLeft + nLeft2, nTop + nTop2, nLeft + nRight2, nTop + nBottom2)
	end

	-- Mats
	wndCurr:FindChild("PopoutCostContainer"):DestroyChildren()
	local bHasMatsForAll = true
	if tCurrTier.arItems then
		for idx = 1, 3 do
			local tCurrItemData = tCurrTier.arItems[idx]
			if tCurrItemData then
				-- Costs
				local wndItemReward = Apollo.LoadForm(self.xmlDoc, "ItemReward", wndCurr:FindChild("PopoutCostContainer"), self)
				self:HelperBuildItemTooltip(wndItemReward, tCurrItemData.itemResource)
				wndItemReward:FindChild("ItemRewardNoMaterials"):Show(not tCurrItemData.bHasEnough)
				wndItemReward:FindChild("ItemRewardSprite"):SetSprite(tCurrItemData.itemResource:GetIcon())
				wndItemReward:FindChild("ItemRewardFrame"):SetText(String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"),tCurrItemData.itemResource:GetBackpackCount(), tCurrItemData.nCount))
				if tCurrItemData.bHasEnough then
					wndItemReward:FindChild("ItemRewardFrame"):SetTextColor(ApolloColor.new("ffffffff"))
				else
					bHasMatsForAll = false
					wndItemReward:FindChild("ItemRewardFrame"):SetTextColor(ApolloColor.new("ffb80000"))
				end
			end
		end
	end
	wndCurr:FindChild("PopoutCostContainer"):ArrangeChildrenHorz(1)

	-- Build Btn
	local strButtonText = Apollo.GetString("BuildMap_BuildBtn")
	local bEnableBuildBtn = true
	if not bHasMatsForAll then
		strButtonText = Apollo.GetString("BuildMap_NeedMoreMats")
		bEnableBuildBtn = false
	elseif tCurrTier.bIsActive and setNode:IsInfiniteDuration() then
		strButtonText = Apollo.GetString("BuildMap_Built")
	elseif tCurrTier.bIsActive then
		strButtonText = String_GetWeaselString(Apollo.GetString("BuildMap_AddTime"), self:HelperConvertToTime(setNode:GetRemainingTime()))
	elseif tCurrTier.bObsolete then
		strButtonText = Apollo.GetString("BuildMap_BetterTier")
		bEnableBuildBtn = false
	end
	wndCurr:FindChild("PopoutBuildBtn"):SetText(strButtonText)
	wndCurr:FindChild("PopoutBuildBtn"):Enable(bEnableBuildBtn)
	wndCurr:FindChild("PopoutBuildBtn"):SetData({setNode, nTier})
	wndCurr:Invoke()
	wndHandler:AttachWindow(wndCurr)
	

	self:ShowMapHover(setNode)

	local wndSelectionContainer = self.wndMain:FindChild("BottomSection:SelectionItemContainer")
	local nHScrollPos = wndSelectionContainer:GetHScrollPos()
	wndSelectionContainer:RecalculateContentExtents()
	wndSelectionContainer:SetHScrollPos(nHScrollPos)
end

function BuildMap:OnSelectionItemPopOutClosed(wndHandler, wndControl)
	wndHandler:Destroy()
end

function BuildMap:OnPopoutBuildBtn(wndHandler, wndControl) -- PopoutBuildBtn, data is { node, tier }
	if wndHandler and wndHandler:GetData() then
		wndHandler:GetData()[1]:BuildTier(wndHandler:GetData()[2])
		for key, wndCurr in pairs(self.wndMain:FindChild("BottomSection:SelectionItemContainer"):GetChildren()) do
			if wndCurr and wndCurr:FindChild("SelectionItemBtn") then
				wndCurr:FindChild("SelectionItemBtn"):SetCheck(false)
			end
		end
		self:OnSettlerHubUpdated()
	end
end

function BuildMap:ShowMapHover(setNode)
	if self.wndLastMouseEnter then
		self.wndMain:FindChild("TopSection:WorldMap"):RemoveObject(self.wndLastMouseEnter)
	end

	if not self.nNumNodes or self.nNumNodes <= 1 then
		return
	end

	local tInfo =
	{
		strIcon = "sprMM_QuestZonePulse",
		strIconEdge = "sprMM_QuestZonePulse",
		crEdge = CColor.new(1, 1, 1, 1),
		crObject = CColor.new(1, 1, 1, 1),
	}
	self.wndLastMouseEnter = self.wndMain:FindChild("TopSection:WorldMap"):AddObject(self.eOverlayType, setNode:GetPosition(), setNode:GetName(), tInfo, {bNeverShowOnEdge=true}, false, setNode)
end

function BuildMap:HideMapHover() -- Also SelectionItemBtn uncheck
	if self.wndLastMouseEnter then
		self.wndMain:FindChild("TopSection:WorldMap"):RemoveObject(self.wndLastMouseEnter)
	end
end

-----------------------------------------------------------------------------------------------
-- Helper Methods and Window Closed
-----------------------------------------------------------------------------------------------

function BuildMap:OnWindowClosed()
	Event_CancelSettlerHub()
end

function BuildMap:OnCloseVendorWindow()
	if self.bKeepWindowOpen then
		return
	end
	self:OnCloseBtn()
end

function BuildMap:OnCloseBtn() -- SettlerBuildResult
	if self.wndMain and self.wndMain:IsValid() then	
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		Event_CancelSettlerHub()
		self.wndMain:Destroy()
		
	end
end

function BuildMap:HelperConvertToTime(nArg)
	local nInSeconds = math.floor(nArg / 1000)

	local nHours = math.floor(nInSeconds / 3600)
	if nHours > 0 then 
		return String_GetWeaselString(Apollo.GetString("BuildMap_Hours"), nHours) 
	end

	local nMins = math.floor(nInSeconds / 60 - (nHours * 60))
	if nMins > 0 then 
		return String_GetWeaselString(Apollo.GetString("BuildMap_Mins"), nMins) 
	end

	if nInSeconds > 0 then 
		return String_GetWeaselString(Apollo.GetString("BuildMap_Mins"), 1)
	end
	--return math.floor(nInSeconds - (nHours * 3600) - (nMins * 60))

	return ""
end

function BuildMap:HelperBuildItemTooltip(wndArg, itemCurr)
	wndArg:SetTooltipDoc(nil)
	wndArg:SetTooltipDocSecondary(nil)
	local itemEquipped = itemCurr:GetEquippedItemForItemType()
	Tooltip.GetItemTooltipForm(self, wndArg, itemCurr, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
	--if itemEquipped then -- OLD
	--	Tooltip.GetItemTooltipForm(self, wndArg, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = itemCurr})
	--end
end

function BuildMap:FactoryProduce(wndParent, strFormName, tObject)
	local wnd = wndParent:FindChildByUserData(tObject)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(tObject)
	end
	return wnd
end

---------------------------------------------------------------------------------------------------
-- BuildMapForm Functions
---------------------------------------------------------------------------------------------------

function BuildMap:OnKeepWindowBtnCheck( wndHandler, wndControl, eMouseButton )
	self.bKeepWindowOpen = wndControl:IsChecked()
end

local BuildMapInst = BuildMap:new()
BuildMapInst:Init()
