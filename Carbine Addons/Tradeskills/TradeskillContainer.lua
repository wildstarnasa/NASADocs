-----------------------------------------------------------------------------------------------
-- Client Lua Script for TradeskillContainer
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local TradeskillContainer = {}

local knSaveVersion = 2

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
	Apollo.RegisterEventHandler("WorkOrderLocate", 						"OnLocateAchievement", self) -- Clicking a work order quest
	Apollo.RegisterEventHandler("FloatTextPanel_ToggleTechTreeWindow", 	"OnLocateAchievement", self) -- Clicking view btn on achievement notification

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

	if self.wndMain:IsVisible() then
		self.wndMain:Close()
	else
		self.wndMain:Invoke()
		self:RedrawAll()
	end
end

function TradeskillContainer:OnLocateAchievement(idSchematic, achData)
	if GameLib.GetPlayerUnit():IsCasting() then
		return
	end

	local tSchematicInfo = nil
	if idSchematic then
		tSchematicInfo = CraftingLib.GetSchematicInfo(idSchematic)
	end

	if tSchematicInfo and tSchematicInfo.nParentSchematicId then -- Replace sub variants with their parent, we will open to their parent's page
		idSchematic = tSchematicInfo.nParentSchematicId
	end

	if tSchematicInfo and tSchematicInfo.bIsKnown then
		--send to schematics
		self.wndMain:FindChild("SchematicsMainForm"):Show(true)
		self.wndMain:FindChild("AchievementsMainForm"):Show(false)
		self.wndMain:FindChild("TalentsMainForm"):Show(false)
		self.wndMain:FindChild("ToggleSchematicsBtn"):SetCheck(true)
		self.wndMain:FindChild("ToggleAchievementBtn"):SetCheck(false)
		self.wndMain:FindChild("ToggleTalentsBtn"):SetCheck(false)
		Event_FireGenericEvent("GenericEvent_InitializeSchematicsTree", self.wndMain:FindChild("SchematicsMainForm"), idSchematic, nil)
	elseif not tSchematicInfo or (tSchematicInfo and tSchematicInfo.achSource ) or achData then
		--send to techtree
		self.wndMain:FindChild("SchematicsMainForm"):Show(false)
		self.wndMain:FindChild("AchievementsMainForm"):Show(true)
		self.wndMain:FindChild("TalentsMainForm"):Show(false)
		self.wndMain:FindChild("ToggleSchematicsBtn"):SetCheck(false)
		self.wndMain:FindChild("ToggleAchievementBtn"):SetCheck(true)
		self.wndMain:FindChild("ToggleTalentsBtn"):SetCheck(false)
		Event_FireGenericEvent("GenericEvent_InitializeAchievementTree", self.wndMain:FindChild("AchievementsMainForm"), (tSchematicInfo and tSchematicInfo.achSource or achData))
	end
	self.wndMain:Invoke()
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
t="" Template="Default" TooltipType="OnCursor" Name="SwapTimeWarningContainer" BGColor="ffffffff" TextColor="ff7fffb9" TooltipColor="" TextId="" TooltipFont="CRB_InterfaceSmall" Tooltip="" TooltipId="TradeskillTrainer_MaxCDTooltip" IgnoreMouse="1" IgnoreTooltipDelay="1" HideInEditor="0" NewControlDepth="1" Visible="0">
                        <Pixie LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0" TAnchorOffset="53" RAnchorPoint="0" RAnchorOffset="42" BAnchorPoint="0" BAnchorOffset="85" BGColor="ffffffff" Font="Default" TextColor="ffffffff" Text="" Sprite="CRB_Basekit:kitIcon_NewDisabled" Line="0"/>
                        <Pixie LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0" TAnchorOffset="114" RAnchorPoint="0" RAnchorOffset="42" BAnchorPoint="0" BAnchorOffset="193" BGColor="ffffffff" Font="Default" TextColor="ffffffff" Text="" Sprite="CRB_Basekit:kitIcon_NewDisabled" Line="0"/>
                        <Pixie LAnchorPoint="1" LAnchorOffset="-45" TAnchorPoint="0" TAnchorOffset="53" RAnchorPoint="1" RAnchorOffset="-8" BAnchorPoint="0" BAnchorOffset="85" BGColor="ffffffff" Font="Default" TextColor="ffffffff" Text="" Sprite="CRB_Basekit:kitIcon_NewDisabled" Line="0"/>
                        <Pixie LAnchorPoint="1" LAnchorOffset="-45" TAnchorPoint="0" TAnchorOffset="114" RAnchorPoint="1" RAnchorOffset="-8" BAnchorPoint="0" BAnchorOffset="193" BGColor="ffffffff" Font="Default" TextColor="ffffffff" Text="" Sprite="CRB_Basekit:kitIcon_NewDisabled" Line="0"/>
                        <Control Class="Window" LAnchorPoint="1" LAnchorOffset="-131" TAnchorPoint="0" TAnchorOffset="1" RAnchorPoint="1" RAnchorOffset="-8" BAnchorPoint="0" BAnchorOffset="21" RelativeToClient="1" Font="CRB_Interface9_B" Text="" Template="Default" TooltipType="OnCursor" Name="SwapTimeWarningLabel" BGColor="ffffffff" TextColor="ff7fffb9" TooltipColor="" TextId="CRB__2" DT_RIGHT="1" DT_CENTER="0" DT_VCENTER="0" Tooltip=""/>
                    </Control>
                </Control>
                <Control Class="Window" LAnchorPoint="0" LAnchorOffset="5" TAnchorPoint="1" TAnchorOffset="-175" RAnchorPoint="1" RAnchorOffset="-5" BAnchorPoint="1" BAnchorOffset="0" RelativeToClient="0" Font="CRB_InterfaceMedium" Text="" BGColor="UI_WindowBGDefault" TextColor="UI_WindowTitleGray" Template="Default" TooltipType="OnCursor" Name="BotchCraftBlocker" TooltipColor="" Picture="1" IgnoreMouse="0" Sprite="BK3:sprHolo_Alert_Confirm" NewControlDepth="5" HideInEditor="1" DT_CENTER="1" DT_VCENTER="1" TextId="" DT_WORDBREAK="1" NoClip="1" Visible="0" SwallowMouseClicks="1">
                    <Pixie LAnchorPoint="0" LAnchorOffset="30" TAnchorPoint="0" TAnchorOffset="30" RAnchorPoint="1" RAnchorOffset="-30" BAnchorPoint="1" BAnchorOffset="-30" BGColor="UI_WindowBGDefault" Font="CRB_InterfaceMedium_B" TextColor="UI_TextHoloTitle" Text="" TextId="TradeskillTrainer_FinishCraftsFirst" DT_CENTER="1" DT_VCENTER="1" DT_WORDBREAK="1" Line="0"/>
                </Control>
            </Control>
        </Control>
        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="0" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="1" RAnchorOffset="0" BAnchorPoint="1" BAnchorOffset="0" RelativeToClient="1" Font="Default" Text="" Template="Metal_Primary_NoNav" Name="BGBorder" Picture="0" BGColor="ffffffff" TextColor="ffffffff" TextId="" IgnoreMouse="1" Sprite="" NewControlDepth="10" TooltipColor="" Border="1" UseTemplateBG="1" HideInEditor="0"/>
        <Event Name="WindowClosed" Function="OnWindowClosed"/>
        <Control Class="Button" Base="CRB_Basekit:kitBtn_Close" Font="Thick" ButtonType="PushButton" RadioGroup="" LAnchorPoint="1" 