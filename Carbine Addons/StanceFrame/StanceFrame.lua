-----------------------------------------------------------------------------------------------
-- Client Lua Script for StanceFrame
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
 
-----------------------------------------------------------------------------------------------
-- StanceFrame Module Definition
-----------------------------------------------------------------------------------------------
local StanceFrame = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------

function StanceFrame:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.arStances = {}

    return o
end

function StanceFrame:Init()
    Apollo.RegisterAddon(self)
end
 

-----------------------------------------------------------------------------------------------
-- StanceFrame OnLoad
-----------------------------------------------------------------------------------------------

function StanceFrame:OnLoad()
	--[[ TODO DEPRECATED: Moved into Action Bar Frame
    Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
	Apollo.RegisterEventHandler("StanceChanged", "OnStanceChanged", self)
    
    -- load our forms
    self.wndMain = Apollo.LoadForm("StanceFrame.xml", "StanceFrameForm", "FixedHudStratum", self)
	self.wndStanceEntry = self.wndMain:FindChild("StanceEntry")
    self.wndMain:Show(false)
    
	self.wndMenu = Apollo.LoadForm("StanceFrame.xml", "StanceSelectionMenu", "FixedHudStratum", self)
	self.wndStanceContainer = self.wndMenu:FindChild("StanceContainer")
	self.wndMain:FindChild("StanceOptionToggle"):AttachWindow(self.wndMenu)
	self.wndMenu:Show(false)

	if GameLib.GetPlayerUnit() then
		self:OnCharacterCreated()
	end
	]]--
end


-----------------------------------------------------------------------------------------------
-- StanceFrame Functions
-----------------------------------------------------------------------------------------------

function StanceFrame:HelperBuildStanceTooltip(splActive, splPassive)
	local strTooltip = ""
	local strActiveName = splActive:GetName() or ""
	local strPassiveName = splPassive:GetName() or ""
	
	--local strStanceLabel = string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"ff2f94ac\">%s</T>", "Stance: ")
	local strPassiveLabel = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff2f94ac\">%s</T>", Apollo.GetString("ActionBar_Passive")) 
	local strActive = string.format("<T Font=\"CRB_InterfaceMedium_B\" TextColor=\"ffffffff\">%s</T>", strActiveName)
	local strPassive = string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff31fcf6\">%s</T>", strPassiveName)
	
	strTooltip = string.format("<P>%s</P>", strActive)
	
	if strPassiveName ~= "" then
		strTooltip = strTooltip .. string.format("<P>%s</P>", strPassiveLabel .. strPassive)
	end
	
	return strTooltip
end

-----------------------------------------------------------------------------------------------
-- StanceFrameForm Functions
-----------------------------------------------------------------------------------------------

function StanceFrame:OnStanceOptionToggle( wndHandler, wndControl, eMouseButton )
	self.wndMenu:Show(not self.wndMenu:IsShown())
end

function  StanceFrame:OnCharacterCreated()
	local unitPlayer = GameLib.GetPlayerUnit()
	local tStances = GameLib.GetClassInnateAbilitySpells()
	local nStanceCount = tStances.nSpellCount
	
	self.wndStanceContainer:DestroyChildren()
	
	for idx = 1, tStances.nSpellCount do
		self.arStances[idx] = 
		{
			splActive = tStances.tSpells[(2 * idx) - 1],
			splPassive = tStances.tSpells[2 * idx],
			wndStance = Apollo.LoadForm("StanceFrame.xml", "StanceEntry", self.wndStanceContainer, self)
		}
		self.arStances[idx].wndStance:FindChild("StanceIcon"):SetSprite(self.arStances[idx].splPassive:GetIcon())
		self.arStances[idx].wndStance:SetData(idx)
		self.arStances[idx].wndStance:SetTooltip(self:HelperBuildStanceTooltip(self.arStances[idx].splActive, self.arStances[idx].splPassive))
	end
	
	self.wndStanceContainer:ArrangeChildrenVert(1)
	self.wndMain:Show(nStanceCount > 0)
	self.wndMenu:ToFront()
	self.wndMain:ToFront()
	
	self:OnStanceChanged()
end

function StanceFrame:OnStanceChanged() 
	local idxStance = GameLib.GetCurrentClassInnateAbilityIndex()
	
	-- todo: this can be part of the event handler and not the button check
	for idx = 1, #self.arStances do
		self.arStances[idx].wndStance:FindChild("StanceBtn"):SetCheck(idx == idxStance)
		self.arStances[idx].wndStance:FindChild("StanceIconBlocker"):Show(idx ~= idxStance)
		
		if idx == idxStance then
			self.wndStanceEntry:FindChild("StanceIcon"):SetSprite(self.arStances[idx].splPassive:GetIcon())
			self.wndStanceEntry:SetData(idx)
			self.wndStanceEntry:SetTooltip(self:HelperBuildStanceTooltip(self.arStances[idx].splActive, self.arStances[idx].splPassive))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- StanceSelectionMenu Functions
---------------------------------------------------------------------------------------------------

function StanceFrame:OnCloseBtn(wndHandler, wndControl)
	wndControl:GetParent():Show(false)
end

---------------------------------------------------------------------------------------------------
-- StanceEntry Functions
---------------------------------------------------------------------------------------------------

function StanceFrame:OnStanceBtn( wndHandler, wndControl, eMouseButton )
	local idxStance = wndControl:GetParent():GetData()
	GameLib.SetCurrentClassInnateAbilityIndex(idxStance)
	self:OnStanceChanged()
	
	self.wndMenu:Show(false)
end

-----------------------------------------------------------------------------------------------
-- StanceFrame Instance
-----------------------------------------------------------------------------------------------
local StanceFrameInst = StanceFrame:new()
StanceFrameInst:Init()
