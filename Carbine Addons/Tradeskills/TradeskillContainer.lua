-----------------------------------------------------------------------------------------------
-- Client Lua Script for TradeskillContainer
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local TradeskillContainer = {}

local knSaveVersion = 1

function TradeskillContainer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function TradeskillContainer:Init()
    Apollo.RegisterAddon(self)
end

function TradeskillContainer:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("TradeskillContainer.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function TradeskillContainer:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 	"OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady", 		"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("GenericEvent_OpenToSpecificSchematic", "OnOpenToSpecificSchematic", self) -- Not Used Yet
	Apollo.RegisterEventHandler("GenericEvent_OpenToSpecificTechTree", 	"OnOpenToSpecificTechTree", self)
	Apollo.RegisterEventHandler("GenericEvent_OpenToSearchSchematic", 	"OnOpenToSearchSchematic", self)

	Apollo.RegisterEventHandler("TradeskillLearnedFromTHOR", 			"OnAlwaysShowTradeskills", self)
	Apollo.RegisterEventHandler("TradeSkills_Learned", 					"OnAlwaysShowTradeskills", self)
	Apollo.RegisterEventHandler("AlwaysShowTradeskills",				"OnAlwaysShowTradeskills", self)
	Apollo.RegisterEventHandler("AlwaysHideTradeskills",				"OnAlwaysHideTradeskills", self)
	Apollo.RegisterEventHandler("ToggleTradeskills", 					"OnToggleTradeskills", self)
	Apollo.RegisterEventHandler("WorkOrderLocate", 						"OnWorkOrderLocate", self) -- Clicking a work order quest

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "TradeskillContainerForm", nil, self)

	if self.wndMain == nil then
		return Apollo.AddonLoadStatus.LoadingError
	end

	self.wndMain:FindChild("ToggleSchematicsBtn"):AttachWindow(self.wndMain:FindChild("SchematicsMainForm"))
	self.wndMain:FindChild("ToggleAchievementBtn"):AttachWindow(self.wndMain:FindChild("AchievementsMainForm"))
	self.wndMain:FindChild("ToggleTalentsBtn"):AttachWindow(self.wndMain:FindChild("TalentsMainForm"))
	self.wndMain:FindChild("ToggleSchematicsBtn"):SetCheck(true)
	self.wndMain:Show(false, true)

	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
end

function TradeskillContainer:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_Tradeskills"), {"ToggleTradeskills", "Tradeskills", "Icon_Windows32_UI_CRB_InterfaceMenu_Tradeskills"})
end

function TradeskillContainer:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("CRB_Tradeskills")})
end

function TradeskillContainer:OnClose(wndHandler, wndControl)
	if wndHandler == wndControl then
		self.wndMain:Show(false)
	end
end

function TradeskillContainer:OnAlwaysShowTradeskills()
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end

	self.wndMain:ToFront()
	self.wndMain:Show(true)
	self:RedrawAll()
end

function TradeskillContainer:OnAlwaysHideTradeskills()
	self.wndMain:Show(false)
end

function TradeskillContainer:OnToggleTradeskills()
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end

	self.wndMain:Show(not self.wndMain:IsVisible())
	self.wndMain:ToFront()
	self:RedrawAll()
end

function TradeskillContainer:OnWorkOrderLocate(nSchematicId)
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end

	self.wndMain:ToFront()
	self.wndMain:Show(true)
	local tSchematicInfo = CraftingLib.GetSchematicInfo(nSchematicId)

	if tSchematicInfo.bIsKnown then
		self.wndMain:FindChild("SchematicsMainForm"):Show(true)
		self.wndMain:FindChild("AchievementsMainForm"):Show(false)
		self.wndMain:FindChild("TalentsMainForm"):Show(false)
		self.wndMain:FindChild("ToggleSchematicsBtn"):SetCheck(true)
		self.wndMain:FindChild("ToggleAchievementBtn"):SetCheck(false)
		self.wndMain:FindChild("ToggleTalentsBtn"):SetCheck(false)
		Event_FireGenericEvent("GenericEvent_InitializeSchematicsTree", self.wndMain:FindChild("SchematicsMainForm"), nSchematicId)
	else
		self.wndMain:FindChild("SchematicsMainForm"):Show(false)
		self.wndMain:FindChild("AchievementsMainForm"):Show(true)
		self.wndMain:FindChild("TalentsMainForm"):Show(false)
		self.wndMain:FindChild("ToggleSchematicsBtn"):SetCheck(false)
		self.wndMain:FindChild("ToggleAchievementBtn"):SetCheck(true)
		self.wndMain:FindChild("ToggleTalentsBtn"):SetCheck(false)
		Event_FireGenericEvent("GenericEvent_InitializeAchievementTree", self.wndMain:FindChild("AchievementsMainForm"), tSchematicInfo.achSource)
	end
	--self:RedrawAll()
end

function TradeskillContainer:OnOpenToSpecificTechTree(achievementData)
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end

	self.wndMain:ToFront()
	self.wndMain:Show(true)
	self.wndMain:FindChild("SchematicsMainForm"):Show(false)
	self.wndMain:FindChild("AchievementsMainForm"):Show(true)
	self.wndMain:FindChild("TalentsMainForm"):Show(false)
	self.wndMain:FindChild("ToggleSchematicsBtn"):SetCheck(false)
	self.wndMain:FindChild("ToggleAchievementBtn"):SetCheck(true)
	self.wndMain:FindChild("ToggleTalentsBtn"):SetCheck(false)
	Event_FireGenericEvent("GenericEvent_InitializeAchievementTree", self.wndMain:FindChild("AchievementsMainForm"), achievementData)
	--self:RedrawAll()
end

function TradeskillContainer:OnOpenToSpecificSchematic(nSchematicId)
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end

	self.wndMain:ToFront()
	self.wndMain:Show(true)
	self.wndMain:FindChild("SchematicsMainForm"):Show(true)
	self.wndMain:FindChild("AchievementsMainForm"):Show(false)
	self.wndMain:FindChild("TalentsMainForm"):Show(false)
	self.wndMain:FindChild("ToggleSchematicsBtn"):SetCheck(true)
	self.wndMain:FindChild("ToggleAchievementBtn"):SetCheck(false)
	self.wndMain:FindChild("ToggleTalentsBtn"):SetCheck(false)
	Event_FireGenericEvent("GenericEvent_InitializeSchematicsTree", self.wndMain:FindChild("SchematicsMainForm"), nSchematicId, nil)
	--self:RedrawAll()
end

function TradeskillContainer:OnOpenToSearchSchematic(strQuery)
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end

	self.wndMain:ToFront()
	self.wndMain:Show(true)
	self.wndMain:FindChild("SchematicsMainForm"):Show(true)
	self.wndMain:FindChild("AchievementsMainForm"):Show(false)
	self.wndMain:FindChild("TalentsMainForm"):Show(false)
	self.wndMain:FindChild("ToggleSchematicsBtn"):SetCheck(true)
	self.wndMain:FindChild("ToggleAchievementBtn"):SetCheck(false)
	self.wndMain:FindChild("ToggleTalentsBtn"):SetCheck(false)
	Event_FireGenericEvent("GenericEvent_InitializeSchematicsTree", self.wndMain:FindChild("SchematicsMainForm"), nil, strQuery)
	--self:RedrawAll()
end

function TradeskillContainer:OnTopTabBtn(wndHandler, wndControl)
	self:RedrawAll()
end

function TradeskillContainer:RedrawAll()
	-- TODO: We can destroy AchievementsMainForm and SchematicsMainForm's children to save memory when it's closed (after X time)
	if self.wndMain:FindChild("ToggleSchematicsBtn"):IsChecked() then
		Event_FireGenericEvent("GenericEvent_InitializeSchematicsTree", self.wndMain:FindChild("SchematicsMainForm"))
	elseif self.wndMain:FindChild("ToggleAchievementBtn"):IsChecked() then
		Event_FireGenericEvent("GenericEvent_InitializeAchievementTree", self.wndMain:FindChild("AchievementsMainForm"))
	elseif self.wndMain:FindChild("ToggleTalentsBtn"):IsChecked() then
		Event_FireGenericEvent("GenericEvent_InitializeTradeskillTalents", self.wndMain:FindChild("TalentsMainForm"))
	end
end

local TradeskillContainerInst = TradeskillContainer:new()
TradeskillContainerInst:Init()
