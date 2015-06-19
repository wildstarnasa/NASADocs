-----------------------------------------------------------------------------------------------
-- Client Lua Script for Collectables
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- Collectables Module Definition
-----------------------------------------------------------------------------------------------
local Collectables = {} 
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Collectables:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function Collectables:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {}

    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- Collectables OnLoad
-----------------------------------------------------------------------------------------------
function Collectables:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("Collectables.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- Collectables OnDocLoaded
-----------------------------------------------------------------------------------------------
function Collectables:OnDocLoaded()
	if not self.xmlDoc or not self.xmlDoc:IsLoaded() then
		return
	end

	self.wndMain = Apollo.LoadForm(self.xmlDoc, "CollectablesMainForm", nil, self)
	self.wndMain:Show(false, true)

	Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuLoaded", self)
	Apollo.RegisterEventHandler("GenericEvent_RegisterCollectableWindow", "RegisterAddon", self)
	Apollo.RegisterEventHandler("GenericEvent_OpenCollectables", "OnCollectablesOn", self)
	Apollo.RegisterEventHandler("GenericEvent_RequestCollectablesReady", "OnRequestReady", self)
	Apollo.RegisterEventHandler("GenericEvent_CloseCollectablesWindow", "OnClose", self)

	self.tRegisteredAddonInfo = {}
	
	Event_FireGenericEvent("GenericEvent_CollectablesReady", self.wndMain:FindChild("HoloBG"))
end

function Collectables:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("Collectables_Header"), nSaveVersion = 2})
end

function Collectables:OnInterfaceMenuLoaded()
	local tData = {"GenericEvent_OpenCollectables", "", "Icon_Windows32_UI_CRB_InterfaceMenu_MountCustomization"}
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("Collectables_Header"), tData)
end

function Collectables:OnRequestReady()
	Event_FireGenericEvent("GenericEvent_CollectablesReady", self.wndMain:FindChild("HoloBG"))
end

-- wndChild is the window you want to add to the container.  
-- nTabOrder determines the order the addon will appear in the tabs.  Carbine addons should be in increments of 100.
-- strEventBase is the base name for the open/close events.
function Collectables:RegisterAddon(nTabOrder, strEventBase, strTabLabel)
	if nTabOrder and strEventBase and strTabLabel then
		self.tRegisteredAddonInfo[strTabLabel] = {strEventName = strEventBase, nTabOrder = nTabOrder}
		
		--Addons should pass the event name along with this event
		Apollo.RegisterEventHandler("GenericEvent_OpenTo" .. strEventBase, "OnOpenTab", self)
	end
	
	self:DrawTabs()
end

-- This only needs to be done when an addon registers.
function Collectables:DrawTabs()
	local wndHeaderContainer = self.wndMain:FindChild("HeaderButtons")
	
	wndHeaderContainer:DestroyChildren()
	
	local arOrderedAddonList = {}
	
	for strLabel, tInfo in pairs(self.tRegisteredAddonInfo) do
		table.insert(arOrderedAddonList, strLabel)
	end
	
	if #arOrderedAddonList > 1 then
		table.sort(arOrderedAddonList, function(a,b) return self.tRegisteredAddonInfo[a].nTabOrder < self.tRegisteredAddonInfo[b].nTabOrder end)
	end
	
	local nNumTabs = table.getn(arOrderedAddonList)
	local nTabWidth = nNumTabs and 1/nNumTabs or 0
	
	for idx, strLabel in ipairs(arOrderedAddonList) do
		local wndTab = Apollo.LoadForm(self.xmlDoc, "TabItem", wndHeaderContainer, self)
		
		local strButtonSprite = "BK3:btnMetal_TabMainMid"
		
		if idx == 1 then
			if #arOrderedAddonList > 1 then
				strButtonSprite = "BK3:btnMetal_TabMainLeft"
			end
			
			self.wndCheckedTab = wndTab
		elseif idx == #arOrderedAddonList then
			strButtonSprite = "BK3:btnMetal_TabMainRight"
		end
		
		wndTab:ChangeArt(strButtonSprite)

		wndTab:SetData(tostring(self.tRegisteredAddonInfo[strLabel].strEventName))
		wndTab:SetText(strLabel)
		
		wndTab:SetAnchorPoints(nTabWidth * (idx - 1), 0, nTabWidth * idx, 1)
	end
end

-- fired whenever a child window tells the collectables window to open to a specific tab
function Collectables:OnOpenTab(strEvent)
	if strEvent and tostring(strEvent) then
		for idx, wndTab in pairs(self.wndMain:FindChild("HeaderButtons"):GetChildren()) do
			if not wndTab:GetData() == tostring(strEvent) then
				self.wndCheckedTab = wndTab
			end
		end
		
		self:OnCollectablesOn()
	end
end

function Collectables:OnCollectablesOn()
	self.wndMain:Show(true)
	
	if self.wndCheckedTab then
		self.wndCheckedTab:SetCheck(true)
		self:OnTabCheck(self.wndCheckedTab, self.wndCheckedTab)
	end
end

function Collectables:OnTabCheck(wndHandler, wndControl)
	if self.wndCheckedTab ~= wndHandler then
		Event_FireGenericEvent("GenericEvent_" .. self.wndCheckedTab:GetData() .. "Unchecked")
	end
	
	Event_FireGenericEvent("GenericEvent_" .. wndHandler:GetData() .. "Checked")
	
	self.wndCheckedTab = wndHandler
end

-- The collectables container will still exist, but the children should be destroyed.
function Collectables:OnClose(wndHandler, wndControl)
	self.wndMain:Show(false, true)
	
	Event_FireGenericEvent("GenericEvent_CollectablesClose")
end

-----------------------------------------------------------------------------------------------
-- Collectables Instance
-----------------------------------------------------------------------------------------------
local CollectablesInst = Collectables:new()
CollectablesInst:Init()
