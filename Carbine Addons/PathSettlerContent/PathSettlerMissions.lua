-----------------------------------------------------------------------------------------------
-- Client Lua Script for ChallengeLog
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
require "AbilityBook"

local PathSettlerMissions = {}

function PathSettlerMissions:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function PathSettlerMissions:Init()
	Apollo.RegisterAddon(self)
end

function PathSettlerMissions:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("PathSettlerMissions.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function PathSettlerMissions:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("CharacterCreated", 	"OnCharacterLoaded", self)

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer and unitPlayer:GetPlayerPathType() == PlayerPathLib.PlayerPathType_Settler then
		self:OnCharacterLoaded()
	end
end

function PathSettlerMissions:OnCharacterLoaded()
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer and unitPlayer:GetPlayerPathType() == PlayerPathLib.PlayerPathType_Settler then
		Apollo.RegisterEventHandler("LoadSettlerMission", 	"LoadFromList", self)

		Apollo.RegisterEventHandler("ChangeWorld", 			"HelperResetUI", self)
		Apollo.RegisterEventHandler("PlayerResurrected", 	"HelperResetUI", self)
		Apollo.RegisterEventHandler("ShowResurrectDialog", 	"HelperResetUI", self)

		Apollo.RegisterTimerHandler("MissionsUpdateTimer", "OnMissionsUpdateTimer", self)

		Apollo.CreateTimer("MissionsUpdateTimer", 0.05, true)
	end
end

function PathSettlerMissions:LoadFromList(pmMission)
	if self.wndMain then
		self.wndMain:Destroy()
		self.wndMain = nil
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "PathSettlerrMissionMain", g_wndDatachron:FindChild("PathContainer"):FindChild("SettlerMissionContainer"), self)
	self.wndMain:SetData(pmMission)
end

-- Note: This gets called from a variety of sources
function PathSettlerMissions:HelperResetUI()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

---------------------------------------------------------------------------------------------------
-- Main Update Timer
---------------------------------------------------------------------------------------------------

function PathSettlerMissions:OnMissionsUpdateTimer()
	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:GetData() or GameLib.GetPlayerUnit():IsDead() then
		return
	end

	local eType = self.wndMain:GetData():GetType()
	if eType == PathMission.PathMissionType_Settler_Hub then
		self:OnHubUpdateTimer()
	elseif eType == PathMission.PathMissionType_Settler_Infrastructure then
		self:OnInfrastructureUpdateTimer()
	elseif eType == PathMission.PathMissionType_Settler_Mayor then
		self:OnMayorUpdateTimer()
	elseif eType == PathMission.PathMissionType_Settler_Sheriff then
		self:OnSheriffUpdateTimer()
	elseif eType == PathMission.PathMissionType_Settler_Scout then
		self:OnScoutUpdateTimer()
	end
end

---------------------------------------------------------------------------------------------------
-- Hub
---------------------------------------------------------------------------------------------------

function PathSettlerMissions:OnHubCloseClick()
	self:HelperResetUI()
end

function PathSettlerMissions:OnHubUpdateTimer()
	if not self.wndMain or not self.wndMain:GetData() then
		return
	end

	local pmMission = self.wndMain:GetData()
	local tHub = PlayerPathLib.GetSettlerHubValues(pmMission)

	if tHub == nil then -- should never happen, but preventing the UI from blowing up if it does
		self:HelperResetUI()
		return
	end

	local wndHub = self.wndMain:FindChild("HubContainer")
	wndHub:Show(true)
	wndResources = wndHub:FindChild("ResContainer"):FindChild("ResourcesContainer")

	-- Big Resource Icons
	local tList = { wndResources:FindChild("Resource0"), wndResources:FindChild("Resource1"), wndResources:FindChild("Resource2") }
	for iResource = 1, 3 do
		local tInfo = tHub.arResources[iResource]
		if tInfo and tInfo.itemResource then
			tList[iResource]:FindChild("HubIcon"):SetSprite(tInfo.itemResource:GetIcon())
			tList[iResource]:FindChild("HubCount"):SetText(tostring(tInfo.nCount))
			--tList[iResource]:SetData({["nIdx"] = i, ["itemResource"] = tInfo.itemResource, ["pmHubMission"] = tHub.pmHubMission})
			Tooltip.GetItemTooltipForm(self, tList[iResource], tInfo.itemResource, {bPrimary = true, bSelling = false, itemCompare = nil})
			tList[iResource]:Show(true)
		else
			tList[iResource]:Show(false)
		end
	end

	-- Status Bars
	wndHub:FindChild("StatsContainerContent"):DestroyChildren()

	for nAvenueType, tAvenue in ipairs(tHub.arAvenues) do
		if tAvenue.nMax > 0 then
			local wndAvenueContainer = Apollo.LoadForm(self.xmlDoc, "SettlerStatsItem", wndHub:FindChild("StatsContainerContent"), self)
			wndAvenueContainer:SetData(pmMission)

			self:DrawAvenueProgressBar(wndAvenueContainer, nAvenueType, tAvenue)
		end
	end

	wndHub:FindChild("StatsContainerContent"):ArrangeChildrenVert(0)

	local strCount = ""
	local strDescription = ""
	local strBlankSpace = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"00ffffff\">%s</T>", "-")
	local strFinal = ""

	if pmMission:IsComplete() then
		strCount = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"ff7fffb9\">%s</T>", Apollo.GetString("SettlerMission_CompletedBuilding"))
		strDescription = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">%s</T>", pmMission:GetSummary())
		strFinal = String_GetWeaselString(strCount, strBlankSpace, strDescription)
	else
		strCount = Apollo.GetString("SettlerMission_BuildingInProgress")
		strCount = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"ff31fcf6\">%s</T>", strCount)
		strDescription = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ffffffff\">%s</T>", pmMission:GetSummary())
		strFinal = String_GetWeaselString(strCount, pmMission:GetNumCompleted(), pmMission:GetNumNeeded(), strBlankSpace, strDescription)
	end

	wndHub:FindChild("MissionBody"):SetText(strFinal)
end

---------------------------------------------------------------------------------------------------
-- Infrastructure Display
---------------------------------------------------------------------------------------------------

function PathSettlerMissions:OnInfrastructureCloseBtn()
	self:HelperResetUI()
end

function PathSettlerMissions:OnInfrastructureUpdateTimer()
	if not self.wndMain or not self.wndMain:GetData() then return end

	local pmMission = self.wndMain:GetData()
	local wndHub = self.wndMain:FindChild("InfrastructureContainer")
	wndHub:Show(true)

	local crContributionsText = nil

	if pmMission:IsComplete() then
		wndHub:FindChild("ContributionsCount"):SetText(Apollo.GetString("SettlerMission_ContributionsCompleted"))
		wndHub:FindChild("ContributionsCount"):SetTextColor(ApolloColor.new("ff7fffb9"))
		crContributionsText = "ff2f94ac"
	else
		wndHub:FindChild("ContributionsCount"):SetText(string.format("[%d/%d]", pmMission:GetNumCompleted(), pmMission:GetNumNeeded()))
		wndHub:FindChild("ContributionsCount"):SetTextColor(ApolloColor.new("ff31fcf6"))
		crContributionsText = "white"
	end

	-- Text and status
	wndHub:FindChild("ContributionsText"):SetText(string.format("<P Font=\"CRB_InterfaceSmall\" TextColor=\"%s\">%s</P>", crContributionsText, pmMission:GetSummary()))
	wndHub:FindChild("ContributionsText"):SetHeightToContentHeight()

	local nHeight = wndHub:FindChild("MissionContainer"):ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndHub:FindChild("MissionContainer"):GetAnchorOffsets()
	wndHub:FindChild("MissionContainer"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight)
	local nBGLeft, nBGTop, nBGRight, nBGBottom = wndHub:FindChild("InfraMissionBack"):GetAnchorOffsets()
	wndHub:FindChild("InfraMissionBack"):SetAnchorOffsets(nBGLeft, nBGTop, nBGRight, nBottom + 8)

	wndHub:RecalculateContentExtents()

	-- Status and/or OOR indicator; we can't get Infrastructure values for a specific one, just the one in our current hub
	--[[local tInfrastructure = PlayerPathLib.GetCurrentSettlerInfrastructure()

	if tInfrastructure == nil or tInfrastructure.mission ~= tMission then --is the viewed mission the same as the current hub's?
		wndHub:FindChild("NoStatus"):Show(true)
		wndHub:FindChild("StatusContainer"):Show(false)
	else
		wndHub:FindChild("NoStatus"):Show(false)
		wndHub:FindChild("StatusContainer"):Show(true)
	end	--]]

	local tInfrastructure = PlayerPathLib.GetInfrastructureStatusForMission(pmMission)
	if not tInfrastructure then --is the viewed mission the same as the current hub's?
		wndHub:FindChild("NoStatus"):Show(true)
		wndHub:FindChild("StatusContainer"):Show(false)
	else
		wndHub:FindChild("NoStatus"):Show(false)
		wndHub:FindChild("StatusContainer"):Show(true)
	end

	if wndHub:FindChild("StatusContainer"):IsShown() then
		local wndContainer = wndHub:FindChild("StatusContainer")

		wndContainer:FindChild("InfraStatusBar"):SetMax(100) -- hardcoded formatting
		wndContainer:FindChild("InfraStatusBar"):SetProgress(0)
		wndContainer:FindChild("InfraStatusText"):SetTextColor(CColor.new(122/255, 122/255, 122/255, 1.0))
		wndContainer:FindChild("InfraStatusBar"):SetProgress(tInfrastructure.nPercent)

		local strInfraStatusText = ""
		local strProgress = ""
		local crStatusColor = CColor.new(1.0, 1.0, 1.0, 1.0)

		if tInfrastructure.eState == PlayerPathLib.SettlerInfrastructureState_Inactive then
			strProgress = Apollo.GetString("SettlerMission_Inactive")
			crStatusColor = CColor.new(192/255, 192/255, 192/255, 1.0)
			strInfraStatusText = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceSmall", "ff707070", Apollo.GetString("SettlerMission_Inactive"))
		elseif tInfrastructure.eState == PlayerPathLib.SettlerInfrastructureState_Building then
			strProgress = String_GetWeaselString(Apollo.GetString("SettlerMission_BuildingProgress"), tInfrastructure.nPercent)
			crStatusColor = CColor.new(1.0, 173/255, 65/255, 1.0)
			strInfraStatusText = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceSmall", "ffffad41", String_GetWeaselString(Apollo.GetString("SettlerMission_BuildingPercent"), tInfrastructure.nPercent))
		elseif tInfrastructure.eState == PlayerPathLib.SettlerInfrastructureState_Built then
			strProgress = String_GetWeaselString(Apollo.GetString("SettlerMission_RemainingResources"), tInfrastructure.nPercent)
			crStatusColor = CColor.new(30/255, 255/255, 4/255, 1.0)
			strInfraStatusText = string.format("<T Font=\"%s\" TextColor=\"%s\">%s</T>", "CRB_InterfaceSmall", "ff1eff04", String_GetWeaselString(Apollo.GetString("SettlerMission_BuiltImprovement"), tInfrastructure.nPercent))
		else
		end

		wndContainer:FindChild("InfraStatusText"):SetText(strProgress)
		wndContainer:FindChild("InfraStatusText"):SetTextColor(crStatusColor)
	end
end

---------------------------------------------------------------------------------------------------
-- Scout Mission
---------------------------------------------------------------------------------------------------

function PathSettlerMissions:OnScoutLocateBtn(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() and wndHandler:GetData():ShowHintArrow() then
		Sound.Play(Sound.PlayUIExplorerActivateGuideArrow) -- TODO: Copy to a settler sound
	end
end

function PathSettlerMissions:OnScoutPlaceBtn(wndHandler, wndControl)
	Event_FireGenericEvent("PlayerPath_NotificationSent", 3, self.wndMain:GetData():GetName()) -- Send an objective completed event
	PlayerPathLib.PathAction()
	self:HelperResetUI() -- Also close out the screen
end

function PathSettlerMissions:OnClaimHintBtn(wndHandler, wndControl)
	if wndHandler and wndHandler:GetData() then
		PlayerPathLib.ExplorerShowHint(wndHandler:GetData())
	end
end

function PathSettlerMissions:OnScoutUpdateTimer()
	if not self.wndMain or not self.wndMain:GetData() then
		return
	end

	local pmClaimMission = self.wndMain:GetData()
	local tScoutInfo = pmClaimMission:GetSettlerScoutInfo()
	local fRatio = tScoutInfo.fRatio
	self.wndMain:FindChild("ScoutContainer"):Show(true)
	self.wndMain:FindChild("ScoutBar"):SetProgress(fRatio)
	self.wndMain:FindChild("ScoutPlaceButton"):Enable(fRatio >= 1)
	self.wndMain:FindChild("ScoutPlaceButton"):SetText(tScoutInfo.strButton)
	self.wndMain:FindChild("ScoutLocateButton"):Enable(fRatio < 1)
	self.wndMain:FindChild("ScoutLocateButton"):SetData(pmClaimMission)
	self.wndMain:FindChild("ScoutTitle"):SetText(String_GetWeaselString(Apollo.GetString("FloatText_MissionProgress"), pmClaimMission:GetName(), pmClaimMission:GetNumCompleted(), pmClaimMission:GetNumNeeded()))

	if fRatio > 0 then
		self.wndMain:FindChild("ScoutLabel"):SetText(Apollo.GetString("SettlerMission_CoordinatesReached"))
	else
		self.wndMain:FindChild("ScoutLabel"):SetText(Apollo.GetString("SettlerMission_SignalStrength"))
	end
end

---------------------------------------------------------------------------------------------------
-- Mayor and Sheriff Mission
---------------------------------------------------------------------------------------------------

function PathSettlerMissions:OnMayorUpdateTimer()
	local pmMission = self.wndMain:GetData()
	local tInfo = pmMission:GetSettlerMayorInfo()

	if pmMission and pmMission:IsComplete() then
		self:HelperResetUI()
	elseif pmMission and tInfo then
		self:BuildChecklist(pmMission, tInfo)
	end
end

function PathSettlerMissions:OnSheriffUpdateTimer()
	local pmMission = self.wndMain:GetData()
	local tInfo = pmMission:GetSettlerSheriffInfo()

	if pmMission and pmMission:IsComplete() then
		self:HelperResetUI()
	elseif pmMission and tInfo then
		self:BuildChecklist(pmMission, tInfo)
	end
end

---------------------------------------------------------------------------------------------------
-- Shared Checklist
---------------------------------------------------------------------------------------------------

function PathSettlerMissions:BuildChecklist(pmMission, tInfo)
	self.wndMain:FindChild("ChecklistContainer"):Show(true)
	self.wndMain:FindChild("ChecklistTitle"):SetText(pmMission:GetName())

	for idx, tCurrInfo in pairs(tInfo) do
		if tCurrInfo.strDescription and string.len(tCurrInfo.strDescription) > 0 then -- Since we get all 8 (including nil) entries and this is how we filter
			local wndCurr = self:FactoryProduce(self.wndMain:FindChild("ChecklistItemContainer"), "SettlerChecklistItem", idx)
			wndCurr:FindChild("ChecklistItemBtn"):SetData({ pmMission, idx })
			wndCurr:FindChild("ChecklistItemName"):SetText(tCurrInfo.strDescription)
			wndCurr:FindChild("ChecklistCompleteCheck"):SetSprite(tCurrInfo.bIsComplete and "kitIcon_Complete" or "kitIcon_InProgress")
		
			-- Adjust height to match text
			local nNameHeight = wndCurr:FindChild("ChecklistItemName"):GetHeight()
			wndCurr:FindChild("ChecklistItemName"):SetHeightToContentHeight()
			if wndCurr:FindChild("ChecklistItemName"):GetHeight() > nNameHeight then
			
				-- Adjust total height
				local nLeft,nTop,nRight,nBottom = wndCurr:GetAnchorOffsets()
				wndCurr:SetAnchorOffsets(nLeft,nTop,nRight,nBottom + wndCurr:FindChild("ChecklistItemName"):GetHeight() - nNameHeight)
			end
		end
	end

	self.wndMain:FindChild("ChecklistItemContainer"):ArrangeChildrenVert(0)
end

function PathSettlerMissions:OnChecklistItemBtn(wndHandler, wndControl)
	local pmMission = wndHandler:GetData()[1]
	local nIndex = wndHandler:GetData()[2]
	pmMission:ShowPathChecklistHintArrow(nIndex)
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

function PathSettlerMissions:DrawAvenueProgressBar(wndHub, nAvenueType, tAvenue)
	-- TODO: Hardcoded formatting of sprite paths
	-- TODO: Swap to the enum when exposed
	local strSpritePath = ""
	if nAvenueType == 1 then
		strSpritePath = "ClientSprites:Icon_ItemMisc_bag_0001"
	elseif nAvenueType == 2 then
		strSpritePath = "ClientSprites:Icon_ShieldBash"
	elseif nAvenueType == 3 then
		strSpritePath = "ClientSprites:Icon_SkillMisc_UI_srcr_enhncesns"
	end
	wndHub:FindChild("SettlerStatsIcon"):SetSprite(strSpritePath)

	wndHub:FindChild("Description"):SetText(tAvenue.strName)
	wndHub:FindChild("ProgressMeter"):SetMax(tAvenue.nMax)
	wndHub:FindChild("ProgressMeter"):SetProgress(tAvenue.nValue)
	wndHub:FindChild("ProgressText"):SetText(String_GetWeaselString(Apollo.GetString("CRB_ProgressSimple"), tAvenue.nValue, tAvenue.nMax))

	--local l,t,r,b = wndHub:GetAnchorOffsets()
	--return (b-t)
end

function PathSettlerMissions:CalculateMLTimeText(nMilliseconds)
	if nMilliseconds < 0 then
		return ""
	end

	local nInSeconds = math.floor(nMilliseconds / 1000)
	local strPrefix = ""
	local strTime = ""

	if nInSeconds < 60 then
		strPrefix = "00:" -- Will display as 00: + 59
		strTime = string.format("%02.f", nInSeconds)
	else
		local nMins = string.format("%02.f", math.floor(nInSeconds / 60))
		local nSecs = string.format("%02.f", math.floor(nInSeconds - (nMins * 60)))
		strTime = nMins .. ":" .. nSecs
	end

    return string.format("<T Align=\"Center\"><T Font=\"CRB_HeaderGigantic\" TextColor=\"aaaa0000\">%s</T><T Font=\"CRB_HeaderGigantic\" TextColor=\"eeee0000\">%s</T></T>", strPrefix, strTime)
end

function PathSettlerMissions:FactoryProduce(wndParent, strFormName, tObject)
	local wnd = wndParent:FindChildByUserData(tObject)
	if not wnd then
		wnd = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wnd:SetData(tObject)
	end
	return wnd
end

local PathSettlerMissionsInst = PathSettlerMissions:new()
PathSettlerMissionsInst:Init()
