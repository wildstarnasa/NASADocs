-----------------------------------------------------------------------------------------------
-- Client Lua Script for GroupDisplayOptions
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GroupLib"

local GroupDisplayOptions = {}

local ktSubMenus =
{
	"ThresholdDistribution",
	"LootThreshold",
	"Mentoring",
	"JoinRequest",
	"Referral"
}

function GroupDisplayOptions:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function GroupDisplayOptions:Init()
    Apollo.RegisterAddon(self)
end

function GroupDisplayOptions:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GroupDisplayOptions.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function GroupDisplayOptions:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("Group_Updated", 								"RedrawAll", self)
	Apollo.RegisterEventHandler("GenericEvent_UpdateGroupLeaderOptions", 		"RedrawAll", self)
	Apollo.RegisterEventHandler("GenericEvent_InitializeGroupLeaderOptions", 	"Initialize", self)
end

function GroupDisplayOptions:Initialize(wndParent)
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "GroupLeaderOptions", wndParent, self)
	wndParent:AttachWindow(self.wndMain)

	for idx, strMenu in ipairs(ktSubMenus) do
		if strMenu and self.wndMain:FindChild(strMenu) then
			self.wndMain:FindChild(strMenu):AttachWindow(self.wndMain:FindChild(strMenu .. "Area"))
		end
	end

	local tLootThreshold =
	{
		[Item.CodeEnumItemQuality.Inferior] 		= Apollo.GetString("CRB_Inferior"),
		[Item.CodeEnumItemQuality.Average] 			= Apollo.GetString("CRB_Average"),
		[Item.CodeEnumItemQuality.Good] 			= Apollo.GetString("CRB_Good"),
		[Item.CodeEnumItemQuality.Excellent] 		= Apollo.GetString("CRB_Excellent"),
		[Item.CodeEnumItemQuality.Superb] 			= Apollo.GetString("CRB_Superb"),
		[Item.CodeEnumItemQuality.Legendary] 		= Apollo.GetString("CRB_Legendary"),
		[Item.CodeEnumItemQuality.Artifact]	 		= Apollo.GetString("CRB_Artifact")
	}
	self:HelperInitializeWindows(tLootThreshold, "LootThreshold", self.wndMain:FindChild("LootThresholdArea"):FindChild("ItemsContainer"))

	local tThresholdDistribution =
	{
		[GroupLib.LootRule.Master] 			= Apollo.GetString("Group_MasterLoot"),
		[GroupLib.LootRule.NeedBeforeGreed] = Apollo.GetString("Group_NeedVsGreed"),
		[GroupLib.LootRule.RoundRobin] 		= Apollo.GetString("Group_RoundRobin"),
		[GroupLib.LootRule.FreeForAll] 		= Apollo.GetString("Group_FFA"),
	}
	self:HelperInitializeWindows(tThresholdDistribution, "ThresholdDistribution", self.wndMain:FindChild("ThresholdDistributionArea"):FindChild("ItemsContainer"))

	local tInvitationMethod =
	{
		[GroupLib.InvitationMethod.Open] 	= Apollo.GetString("CRB_Open"),
		[GroupLib.InvitationMethod.Neutral]	= Apollo.GetString("CRB_Neutral"),
		[GroupLib.InvitationMethod.Closed]	= Apollo.GetString("CRB_Closed")
	}
	self:HelperInitializeWindows(tInvitationMethod, "JoinRequest", self.wndMain:FindChild("JoinRequestArea"):FindChild("ItemsContainer"))
	self:HelperInitializeWindows(tInvitationMethod, "Referral", self.wndMain:FindChild("ReferralArea"):FindChild("ItemsContainer"))

	self:RedrawAll()
end

---------------------------------------------------------------------------------------------------
-- Group Options Menu
---------------------------------------------------------------------------------------------------

function GroupDisplayOptions:OnSubOptionSet(wndHandler, wndControl)
	local strSubOptionName = wndHandler:GetName()
	local tCurrRules = GroupLib.GetLootRules()

	if strSubOptionName == "LootThreshold" then
		GroupLib.SetLootRules(tCurrRules.eNormalRule, tCurrRules.eThresholdRule, wndHandler:GetData(), tCurrRules.eHarvestRule)
	elseif strSubOptionName == "ThresholdDistribution" then
		GroupLib.SetLootRules(tCurrRules.eNormalRule, wndHandler:GetData(), tCurrRules.eThresholdQuality, tCurrRules.eHarvestRule)
	elseif strSubOptionName == "JoinRequest" then
		GroupLib.SetJoinRequestMethod(wndHandler:GetData())
	elseif strSubOptionName == "Referral" then
		GroupLib.SetReferralMethod(wndHandler:GetData())
	end
end

function GroupDisplayOptions:RedrawAll() -- The button check and various UI calls route here
	if not self.wndMain or not self.wndMain:IsValid() then -- Will rely on the initialize to RedrawAll
		return
	end
	
	local nGroupCount = GroupLib.GetMemberCount()
	if nGroupCount == 0 then
		return
	end

	local tLootRules = GroupLib.GetLootRules()
	self:HelperRedrawSpecific("LootThreshold", tLootRules.eThresholdQuality)
	self:HelperRedrawSpecific("ThresholdDistribution", tLootRules.eThresholdRule)
	self:HelperRedrawSpecific("JoinRequest", GroupLib.GetJoinRequestMethod())
	self:HelperRedrawSpecific("Referral", GroupLib.GetReferralMethod())

	-- Mentoring has a custom redraw
	self:HelperRedrawMentoring()
end

function GroupDisplayOptions:HelperRedrawSpecific(strMenuName, tProvidedValue)
	if not self.wndMain or not self.wndMain:IsValid() or not strMenuName or strMenuName == "" then
		return
	end

	local wndItems = self.wndMain:FindChild(strMenuName .. "Area"):FindChild("ItemsContainer")
	if not wndItems then
		return
	end

	local bIsLeader = GroupLib.AmILeader()
	local bIsInstance = GroupLib.InInstance()
	for idx, wndOption in ipairs(wndItems:GetChildren()) do
		local bIsChecked = wndOption:GetData() == tProvidedValue
		wndOption:Enable(bIsLeader and not bIsInstance)
		wndOption:SetCheck(bIsChecked)
		wndOption:FindChild("CheckIcon"):Show(bIsChecked)

		if not bIsLeader or bIsInstance then -- Priority: Red for disabled, Light Blue for checked, else Dark Blue
			wndOption:FindChild("SubOptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListDisabled"))
		elseif bIsChecked then
			wndOption:FindChild("SubOptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListPressed"))
		else
			wndOption:FindChild("SubOptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListNormal"))
		end
	end

	self.wndMain:FindChild("DisbandGroup"):Enable(bIsLeader and not bIsInstance)
	if bIsLeader and not bIsInstance then
		self.wndMain:FindChild("DisbandGroup"):FindChild("OptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListNormal"))
	else
		self.wndMain:FindChild("DisbandGroup"):FindChild("OptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListDisabled"))
	end

	self.wndMain:FindChild("ResetInstances"):Enable(bIsLeader and not bIsInstance)
	if bIsLeader and not bIsInstance then
		self.wndMain:FindChild("ResetInstances"):FindChild("OptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListNormal"))
	else
		self.wndMain:FindChild("ResetInstances"):FindChild("OptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListDisabled"))
	end

	self.wndMain:FindChild("LeaveGroup"):Enable(true)
	self.wndMain:FindChild("LeaveGroup"):FindChild("OptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListNormal"))

	local bIsInRaid = GroupLib.InRaid()
	self.wndMain:FindChild("ConvertToRaid"):Enable(bIsLeader and not bIsInRaid and not bIsInstance)

	if bIsLeader and not bIsInRaid and not bIsInstance then
		self.wndMain:FindChild("ConvertToRaid"):FindChild("OptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListNormal"))
	else
		self.wndMain:FindChild("ConvertToRaid"):FindChild("OptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListDisabled"))
	end
end

---------------------------------------------------------------------------------------------------
-- Mentoring
---------------------------------------------------------------------------------------------------

function GroupDisplayOptions:HelperRedrawMentoring() -- Also from XML's Mentoring Btn
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	local tMyGroupData = GroupLib.GetGroupMember(1)
	local wndParent = self.wndMain:FindChild("MentoringArea"):FindChild("ItemsContainer")
	wndParent:FindChild("MentoringStopBtn"):SetCheck(false) -- Consider swapping to a button

	if not tMyGroupData then
		return
	end

	local nMemberCount = GroupLib.GetMemberCount()
	local bCanStopMentoring = tMyGroupData.bIsMentoring or tMyGroupData.bIsMentored
	local strMentoringStopBtnColor = ApolloColor.new(bCanStopMentoring and "UI_BtnTextHoloListNormal" or "UI_BtnTextHoloListDisabled")
	wndParent:FindChild("MentoringStopBtn"):Enable(bCanStopMentoring)
	wndParent:FindChild("MentoringStopBtn"):FindChild("SubOptionsBtnText"):SetTextColor(strMentoringStopBtnColor)

	for idx = 1, 4 do
		local tTargetGroupData = GroupLib.GetGroupMember(idx + 1) -- GOTCHA: Off by one "Group Member One" text really means idx2
		local bActivelyMentoringThisPersonAlready = (idx + 1) == tMyGroupData.nMenteeIdx
		local bCanRallyToThisPerson = tTargetGroupData and tTargetGroupData.nLevel < tMyGroupData.nLevel and idx < nMemberCount and not bCanStopMentoring
		local wndCurrBtn = wndParent:FindChild("MentoringSpecificBtn"..idx)
		wndCurrBtn:SetCheck(bActivelyMentoringThisPersonAlready)
		wndCurrBtn:FindChild("CheckIcon"):Show(bActivelyMentoringThisPersonAlready)
		wndCurrBtn:FindChild("SubOptionsBtnText"):SetTextColor(ApolloColor.new(bCanRallyToThisPerson and "UI_BtnTextHoloListNormal" or "UI_BtnTextHoloListDisabled"))
		wndCurrBtn:Enable(bCanRallyToThisPerson)

		-- Button Text
		if tTargetGroupData and bActivelyMentoringThisPersonAlready then
			wndCurrBtn:FindChild("SubOptionsBtnText"):SetText(String_GetWeaselString(Apollo.GetString("Group_MentoringPerson"), tTargetGroupData.strCharacterName))
		elseif tTargetGroupData and tTargetGroupData.strCharacterName then
			wndCurrBtn:FindChild("SubOptionsBtnText"):SetText(String_GetWeaselString(Apollo.GetString("Group_MentorPerson"), tTargetGroupData.strCharacterName))
		else
			wndCurrBtn:FindChild("SubOptionsBtnText"):SetText(Apollo.GetString("Group_RallyMember"..idx))
		end
	end
end

function GroupDisplayOptions:OnMentorSpecificPerson(wndHandler, wndControl)
	local karRallySpecificBtnToIdx =
	{
		["MentoringSpecificBtn1"] = 2,
		["MentoringSpecificBtn2"] = 3,
		["MentoringSpecificBtn3"] = 4,
		["MentoringSpecificBtn4"] = 5,
	}

	local unitTarget = GroupLib.GetUnitForGroupMember(karRallySpecificBtnToIdx[wndHandler:GetName()] or 0)
	if unitTarget then
		GroupLib.AcceptMentoring(unitTarget)
	end

	self:HelperRedrawMentoring()
	self:OnGroupFormatClose()
end

function GroupDisplayOptions:OnStopMentoringBtn(wndHandler, wndControl)
	GroupLib.CancelMentoring()
	self:HelperRedrawMentoring()
	self:OnGroupFormatClose()
end

---------------------------------------------------------------------------------------------------
-- Simple UI buttons
---------------------------------------------------------------------------------------------------

function GroupDisplayOptions:OnLeaveGroup()
	self.wndMain:Show(false)
	self:OnGroupFormatClose()
	Event_FireGenericEvent("GenericEvent_ShowConfirmLeaveDisband", 1)
end

function GroupDisplayOptions:OnDisbandGroup()
	self.wndMain:Show(false)
	self:OnGroupFormatClose()
	Event_FireGenericEvent("GenericEvent_ShowConfirmLeaveDisband", 0)
end

function GroupDisplayOptions:OnResetInstances()
	self.wndMain:Show(false)
	self:OnGroupFormatClose()
	Apollo.ParseInput("/resetinstances") -- TODO: Replace with a library call
end

function GroupDisplayOptions:OnConvertToRaid()
	if self.wndRaidConfirm and self.wndRaidConfirm:IsValid() then
		self.wndRaidConfirm:Destroy()
		self.wndRaidConfirm = nil
	end

	self.wndMain:Show(false)

	self.wndRaidConfirm = Apollo.LoadForm(self.xmlDoc, "RaidConvertConfirmForm", nil, self)
	self.wndRaidConfirm:Show(true)
	self.wndRaidConfirm:ToFront()
end

function GroupDisplayOptions:OnGroupFormatClose() -- clean up on close
	for idx, strMenu in ipairs(ktSubMenus) do
		if strMenu and self.wndMain:FindChild(strMenu) then
			self.wndMain:FindChild(strMenu):SetCheck(false)
			self.wndMain:FindChild(strMenu .. "Area"):Show(false)
			self.wndMain:FindChild(strMenu):FindChild("OptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListNormal"))
		end
	end
end

function GroupDisplayOptions:ResetMouseEnterHighlights(wndHandler, wndControl)
	for idx, strMenu in ipairs(ktSubMenus) do
		if strMenu and self.wndMain:FindChild(strMenu) and self.wndMain:FindChild(strMenu):FindChild("OptionsBtnText") then
			self.wndMain:FindChild(strMenu):FindChild("OptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListNormal"))
		end
	end
	wndHandler:FindChild("OptionsBtnText"):SetTextColor(ApolloColor.new("UI_BtnTextHoloListPressed"))
end

function GroupDisplayOptions:OnOptionsWindowBtnMouseEnter(wndHandler, wndControl)
	wndHandler:SetTextColor(ApolloColor.new("UI_BtnTextHoloListPressedFlyby"))
end

function GroupDisplayOptions:OnOptionsWindowBtnMouseExit(wndHandler, wndControl)
	if not wndHandler:GetParent():IsChecked() then -- TODO: refactor
		wndHandler:SetTextColor(ApolloColor.new("UI_BtnTextHoloListNormal"))
	end
end

---------------------------------------------------------------------------------------------------
-- RaidConvertConfirmForm Functions
---------------------------------------------------------------------------------------------------

function GroupDisplayOptions:OnRaidConfirmNo(wndHandler, wndControl, eMouseButton)
	if self.wndRaidConfirm and self.wndRaidConfirm:IsValid() then
		self.wndRaidConfirm:Destroy()
		self.wndRaidConfirm = nil
	end
end

function GroupDisplayOptions:OnRaidConfirmYes(wndHandler, wndControl, eMouseButton)
	if self.wndRaidConfirm and self.wndRaidConfirm:IsValid() then
		self.wndRaidConfirm:Destroy()
		self.wndRaidConfirm = nil
	end
	self.wndMain:Show(false)
	GroupLib.ConvertToRaid()
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------

function GroupDisplayOptions:HelperInitializeWindows(tLootThreshold, strLuaNameId, wndParent)
	for key, strCurrData in pairs(tLootThreshold) do
		local wndCurr = Apollo.LoadForm(self.xmlDoc, "GroupLeaderSubOption", wndParent, self)
		wndCurr:SetData(key)
		wndCurr:SetName(strLuaNameId)
		wndCurr:FindChild("SubOptionsBtnText"):SetText(strCurrData)
	end
	wndParent:ArrangeChildrenVert(0, function(a,b) return a:GetData() < b:GetData() end)
	wndParent:SetTooltip(GroupLib.AmILeader() and "" or "<P Font=\"CRB_InterfaceMedium\" TextColor=\"ff9d9d9d\">" .. Apollo.GetString("Group_PermissionsDisabledTooltip") .. "</P>")
end

local GroupDisplayOptionsInst = GroupDisplayOptions:new()
GroupDisplayOptionsInst:Init()
