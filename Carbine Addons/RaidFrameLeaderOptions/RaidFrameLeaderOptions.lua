-----------------------------------------------------------------------------------------------
-- Client Lua Script for RaidFrameLeaderOptions
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local RaidFrameLeaderOptions = {}

local ktIdToClassSprite =
{
	[GameLib.CodeEnumClass.Warrior] 		= "Icon_Windows_UI_CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "Icon_Windows_UI_CRB_Engineer",
	[GameLib.CodeEnumClass.Esper] 			= "Icon_Windows_UI_CRB_Esper",
	[GameLib.CodeEnumClass.Spellslinger] 	= "Icon_Windows_UI_CRB_Spellslinger",
	[GameLib.CodeEnumClass.Stalker] 		= "Icon_Windows_UI_CRB_Stalker",
	[GameLib.CodeEnumClass.Medic] 			= "Icon_Windows_UI_CRB_Medic",
}

local ktIdToClassTooltip =
{
	[GameLib.CodeEnumClass.Warrior] 		= "CRB_Warrior",
	[GameLib.CodeEnumClass.Engineer] 		= "CRB_Engineer",
	[GameLib.CodeEnumClass.Esper] 			= "CRB_Esper",
	[GameLib.CodeEnumClass.Spellslinger] 	= "CRB_Spellslinger",
	[GameLib.CodeEnumClass.Stalker] 		= "CRB_Stalker",
	[GameLib.CodeEnumClass.Medic] 			= "CRB_Medic",
}

local knSaveVersion = 7

function RaidFrameLeaderOptions:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function RaidFrameLeaderOptions:Init()
    Apollo.RegisterAddon(self)
end

function RaidFrameLeaderOptions:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	
	local tSaved = 
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSaveVersion = knSaveVersion,
	}
	
	return tSaved
end

function RaidFrameLeaderOptions:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end

function RaidFrameLeaderOptions:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("RaidFrameLeaderOptions.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function RaidFrameLeaderOptions:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("GenericEvent_Raid_ToggleLeaderOptions", 	"Initialize", self)
	Apollo.RegisterEventHandler("Group_Remove",								"OnDestroyAndRedrawAll", self) -- Kicked, or someone else leaves (yourself leaving is Group_Leave)

	Apollo.RegisterTimerHandler("RaidBuildTimer", 							"BuildList", self)
	Apollo.CreateTimer("RaidBuildTimer", 1, true)
	Apollo.StopTimer("RaidBuildTimer")
end

function RaidFrameLeaderOptions:Initialize(bShow)
	if self.wndMain and self.wndMain:IsValid() then
		self.locSavedWindowLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
	end

	if not bShow then
		return
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "RaidFrameLeaderOptionsForm", nil, self)
	self.wndMain:SetSizingMinimum(self.wndMain:GetWidth(), self.wndMain:GetHeight())
	self.wndMain:SetSizingMaximum(self.wndMain:GetWidth(), 1000)
	
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end

	Apollo.StartTimer("RaidBuildTimer")
	self:BuildList()
end

function RaidFrameLeaderOptions:BuildList()
	if not GroupLib.InRaid() then
		if self.wndMain and self.wndMain:IsValid() then
			self.locSavedWindowLoc = self.wndMain:GetLocation()
			self.wndMain:Destroy()
		end
		return
	end

	if not self.wndMain or not self.wndMain:IsValid() or not self.wndMain:IsVisible() then
		return
	end

	local bAmILeader = GroupLib.AmILeader()
	for nIdx = 1, GroupLib.GetMemberCount() do
		local tMemberData = GroupLib.GetGroupMember(nIdx)
		local wndRaidMember = self:FactoryProduce(self.wndMain:FindChild("OptionsMemberContainer"), "OptionsMember", nIdx)
		wndRaidMember:FindChild("KickBtn"):SetData(nIdx)
		wndRaidMember:FindChild("SetDPSBtn"):SetData(nIdx)
		wndRaidMember:FindChild("SetHealBtn"):SetData(nIdx)
		wndRaidMember:FindChild("SetTankBtn"):SetData(nIdx)
		wndRaidMember:FindChild("SetMainTankBtn"):SetData(nIdx)
		wndRaidMember:FindChild("SetMainAssistBtn"):SetData(nIdx)
		wndRaidMember:FindChild("SetRaidAssistBtn"):SetData(nIdx)
		wndRaidMember:FindChild("RaidMemberName"):SetText(tMemberData.strCharacterName)
		wndRaidMember:FindChild("RaidMemberClassIcon"):SetSprite(ktIdToClassSprite[tMemberData.eClassId])
		wndRaidMember:FindChild("RaidMemberClassIcon"):SetTooltip(Apollo.GetString(ktIdToClassTooltip[tMemberData.eClassId]))

		if tMemberData.bIsLeader then
			self.wndMain:FindChild("LockAllRolesBtn"):SetCheck(tMemberData.bRoleLocked)
			local wndLeaderAttachment = self:FactoryProduce(wndRaidMember, "OptionsMemberRaidLeader", "OptionsMemberRaidLeader")
			local bHasText = string.len(wndLeaderAttachment:FindChild("SetRaidLeaderEditBox"):GetText()) > 0
			wndLeaderAttachment:FindChild("SetRaidLeaderConfirmImage"):Show(bHasText)
			wndLeaderAttachment:FindChild("SetRaidLeaderConfirmBtn"):Enable(bHasText)
			wndLeaderAttachment:FindChild("SetRaidLeaderConfirmBtn"):SetData(wndLeaderAttachment)
			wndLeaderAttachment:FindChild("SetRaidLeaderPopupBtn"):AttachWindow(wndLeaderAttachment:FindChild("SetRaidLeaderPopup"))
		end

		wndRaidMember:FindChild("SetMainTankBtn"):Show(not tMemberData.bIsLeader)
		wndRaidMember:FindChild("SetMainAssistBtn"):Show(not tMemberData.bIsLeader)
		wndRaidMember:FindChild("SetRaidAssistBtn"):Show(not tMemberData.bIsLeader)
		wndRaidMember:FindChild("SetRaidAssistBtn"):Enable(bAmILeader)
		wndRaidMember:FindChild("SetMainTankBtn"):SetCheck(tMemberData.bMainTank)
		wndRaidMember:FindChild("SetMainAssistBtn"):SetCheck(tMemberData.bMainAssist)
		wndRaidMember:FindChild("SetRaidAssistBtn"):SetCheck(tMemberData.bRaidAssistant)

		wndRaidMember:FindChild("SetDPSBtn"):SetCheck(tMemberData.bDPS)
		wndRaidMember:FindChild("SetTankBtn"):SetCheck(tMemberData.bTank)
		wndRaidMember:FindChild("SetHealBtn"):SetCheck(tMemberData.bHealer)
	end

	self.wndMain:FindChild("OptionsMemberContainer"):ArrangeChildrenVert(0)
	self.wndMain:FindChild("LockAllRolesBtn"):SetTooltip(Apollo.GetString(self.wndMain:FindChild("LockAllRolesBtn"):IsChecked() and "RaidFrame_UnlockRoles" or "RaidFrame_LockRoles"))
end

-----------------------------------------------------------------------------------------------
-- UI Togglers
-----------------------------------------------------------------------------------------------

function RaidFrameLeaderOptions:OnConfigSetAsDPSCheck(wndHandler, wndControl)
	if wndHandler == wndControl then
		GroupLib.SetRoleDPS(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
	end
end

function RaidFrameLeaderOptions:OnConfigSetAsDPSUncheck(wndHandler, wndControl)
	if wndHandler == wndControl then
		GroupLib.SetRoleDPS(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
	end
end

function RaidFrameLeaderOptions:OnConfigSetAsHealCheck(wndHandler, wndControl)
	if wndHandler == wndControl then
		GroupLib.SetRoleHealer(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
	end
end

function RaidFrameLeaderOptions:OnConfigSetAsHealUncheck(wndHandler, wndControl)
	if wndHandler == wndControl then
		GroupLib.SetRoleHealer(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
	end
end

function RaidFrameLeaderOptions:OnConfigSetAsTankCheck(wndHandler, wndControl) -- SetTankBtn
	if wndHandler == wndControl then
		GroupLib.SetRoleTank(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
	end
end

function RaidFrameLeaderOptions:OnConfigSetAsTankUncheck(wndHandler, wndControl) -- SetTankBtn
	if wndHandler == wndControl then
		GroupLib.SetRoleTank(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
	end
end

function RaidFrameLeaderOptions:OnConfigSetAsMainTankCheck(wndHandler, wndControl)
	GroupLib.SetMainTank(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameLeaderOptions:OnConfigSetAsMainTankUncheck(wndHandler, wndControl)
	GroupLib.SetMainTank(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameLeaderOptions:OnConfigSetAsRaidAssistCheck(wndHandler, wndControl)
	GroupLib.SetRaidAssistant(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameLeaderOptions:OnConfigSetAsRaidAssistUncheck(wndHandler, wndControl)
	GroupLib.SetRaidAssistant(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameLeaderOptions:OnConfigSetAsMainAssistCheck(wndHandler, wndControl)
	GroupLib.SetMainAssist(wndHandler:GetData(), true) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameLeaderOptions:OnConfigSetAsMainAssistUncheck(wndHandler, wndControl)
	GroupLib.SetMainAssist(wndHandler:GetData(), false) -- Will fire event Group_MemberFlagsChanged
end

function RaidFrameLeaderOptions:OnKickBtn(wndHandler, wndControl)
	GroupLib.Kick(wndHandler:GetData(), "")
end

function RaidFrameLeaderOptions:OnLockAllRolesCheck(wndHandler, wndControl)
	for nIdx = 1, GroupLib.GetMemberCount() do
		GroupLib.SetRoleLocked(nIdx, true)
	end
end

function RaidFrameLeaderOptions:OnLockAllRolesUncheck(wndHandler, wndControl)
	for nIdx = 1, GroupLib.GetMemberCount() do
		GroupLib.SetRoleLocked(nIdx, false)
	end
end

-----------------------------------------------------------------------------------------------
-- Change Leader Edit Box
-----------------------------------------------------------------------------------------------

function RaidFrameLeaderOptions:OnSetRaidLeaderConfirmBtn(wndHandler, wndControl)
	local wndParent = wndHandler:GetData()
	local strInput = tostring(wndParent:FindChild("SetRaidLeaderEditBox"):GetText())
	wndParent:FindChild("SetRaidLeaderPopupBtn"):SetCheck(false)

	if not strInput then
		return
	end

	for nIdx = 1, GroupLib.GetMemberCount() do
		local tMemberData = GroupLib.GetGroupMember(nIdx)
		if tMemberData.strCharacterName:lower() == strInput:lower() then
			GroupLib.Promote(nIdx, "")
			self:OnOptionsCloseBtn()
			return
		end
	end

	-- Fail
	wndParent:FindChild("SetRaidLeaderEditBox"):SetText("")
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Party, Apollo.GetString("RaidFrame_PromotionFailed"), "")
end

function RaidFrameLeaderOptions:OnOptionsCloseBtn() -- Also OnSetRaidLeaderConfirmBtn
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		Event_FireGenericEvent("GenericEvent_Raid_UncheckLeaderOptions")
	end
	Apollo.StopTimer("RaidBuildTimer")
end

function RaidFrameLeaderOptions:OnDestroyAndRedrawAll() -- Group_MemberFlagsChanged
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:FindChild("OptionsMemberContainer"):DestroyChildren()
		self:BuildList()
	end
end

function RaidFrameLeaderOptions:FactoryProduce(wndParent, strFormName, tObject)
	local wndNew = wndParent:FindChildByUserData(tObject)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndNew:SetData(tObject)
	end
	return wndNew
end

local RaidFrameLeaderOptionsInst = RaidFrameLeaderOptions:new()
RaidFrameLeaderOptionsInst:Init()
