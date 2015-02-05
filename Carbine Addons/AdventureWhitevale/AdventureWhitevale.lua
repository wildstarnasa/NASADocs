-----------------------------------------------------------------------------------------------
-- Client Lua Script for AdventureWhitevale
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- AdventureWhitevale Module Definition
-----------------------------------------------------------------------------------------------
local AdventureWhitevale = {} 

local knSaveVersion = 1
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function AdventureWhitevale:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function AdventureWhitevale:Init()
    Apollo.RegisterAddon(self)
end

function AdventureWhitevale:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	
	local tSaveData = self.tAdventureInfo
	tSaveData.nSaveVersion = knSaveVersion
		
	return tSaveData
end

function AdventureWhitevale:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	local bIsWhitevaleAdventure = false
	local tActiveEvents = PublicEvent.GetActiveEvents()

	for idx, peEvent in pairs(tActiveEvents) do
		if peEvent:GetEventType() == PublicEvent.PublicEventType_Adventure_Whitevale then
			bIsWhitevaleAdventure = true
		end
	end
	
	self.tAdventureInfo = {}
	
	if bIsWhitevaleAdventure then
		self.bShow = tSavedData.bIsShown
		self.tAdventureInfo.nRep = tSavedData.nRep or 0
		self.tAdventureInfo.nSons = tSavedData.nSons or 0
		self.tAdventureInfo.nRollers = tSavedData.nRollers or 0
		self.tAdventureInfo.nGrinders = tSavedData.nGrinders or 0
	end
end 

-----------------------------------------------------------------------------------------------
-- AdventureWhitevale OnLoad
-----------------------------------------------------------------------------------------------\
function AdventureWhitevale:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("WhitevaleAdventure.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function AdventureWhitevale:OnDocumentReady()
	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)
	
    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
    Apollo.RegisterSlashCommand("whitevaleadv", "OnWhitevaleAdventureOn", self)
    Apollo.RegisterEventHandler("WhitevaleAdvResource", "OnUpdateResource", self)
	Apollo.RegisterEventHandler("WhitevaleAdvShow", "OnShow", self)
	Apollo.RegisterEventHandler("ChangeWorld", "OnHide", self)
	
	self.tSons = {}
	self.tRollers = {}
	self.tGrinders = {}
	
    -- load our forms
    self.wnd = Apollo.LoadForm(self.xmlDoc, "WhitevaleAdventureForm", nil, self)
	self.xmlDoc = nil
	self.wndMain = self.wnd:FindChild("Main")
	self.wndRepBar = self.wndMain:FindChild("Rep")
	self.wndSonsLoyalty = self.wndMain:FindChild("SonsLoyalty")
	self.wndRollersLoyalty = self.wndMain:FindChild("RollersLoyalty")
	self.wndGrindersLoyalty = self.wndMain:FindChild("GrindersLoyalty")
	self.wndSonsLoyalty:FindChild("TitleSons"):SetText(Apollo.GetString("WhitevaleAdv_SonsOfRavok"))
	self.wndRollersLoyalty:FindChild("TitleRollers"):SetText(Apollo.GetString("WhitevaleAdv_RocktownRollers"))
	self.wndGrindersLoyalty:FindChild("TitleGrinders"):SetText(Apollo.GetString("WhitevaleAdv_Geargrinders"))
	self.wndSonsLoyalty:Show(false)
	self.wndRollersLoyalty:Show(false)
	self.wndGrindersLoyalty:Show(false)
	
	for i = 1, 3 do 
		self.tSons[i] = self.wndSonsLoyalty:FindChild("Sons" .. i)
		self.tRollers[i] = self.wndRollersLoyalty:FindChild("Rollers" .. i)
		self.tGrinders[i] = self.wndGrindersLoyalty:FindChild("Grinders" .. i)
	end
	
	self.wndRepBar:SetMax(100)
	self.wndRepBar:SetFloor(0)
	self.wndRepBar:SetProgress(0)
	self.wndRepBar:Show(false)
	--self.wndRepBar:SetText(Apollo.GetString("WhitevaleAdv_Notoriety"))
    self.wnd:Show(false)
    
	if not self.tAdventureInfo then 
		self.tAdventureInfo = {}
	elseif self.bShow then 
		self:OnUpdateResource(self.tAdventureInfo.nRep, self.tAdventureInfo.nSons, self.tAdventureInfo.nRollers, self.tAdventureInfo.nGrinders )
	end
end

function AdventureWhitevale:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wnd, strName = Apollo.GetString("CRB_AdventureWhitevale"), nSaveVersion=2})
end

-----------------------------------------------------------------------------------------------
-- AdventureWhitevale Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/whitevaleadv"
function AdventureWhitevale:OnWhitevaleAdventureOn()
	self.wnd:Show(true) -- show the window
	self.tAdventureInfo.bIsShown = true
end


function AdventureWhitevale:OnUpdateResource(iRep, iSons, iRollers, iGrinders)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end

	self.wnd:Show(true)
	self.wndRepBar:Show(true)
	self.wndRepBar:SetProgress(iRep)
	
	self.tAdventureInfo.bIsShown = true
	
	self.wndSonsLoyalty:Show(true)
	self.wndRollersLoyalty:Show(true)
	self.wndGrindersLoyalty:Show(true)
	self:HideAll()
	
	if iSons > 0 then
		for i = 1, iSons do
			self.tSons[i]:Show(true)
		end
	end
	
	if iRollers > 0 then
		for i = 1, iRollers do
			self.tRollers[i]:Show(true)
		end
	end
	
	if iGrinders > 0 then
		for i = 1, iGrinders do
			self.tGrinders[i]:Show(true)
		end
	end
	
	self.tAdventureInfo.nRep = iRep
	self.tAdventureInfo.nSons = iSons
	self.tAdventureInfo.nRollers = iRollers
	self.tAdventureInfo.nGrinders = iGrinders
end


function AdventureWhitevale:HideAll()
	for i = 1, 3 do
		self.tSons[i]:Show(false)
		self.tRollers[i]:Show(false)
		self.tGrinders[i]:Show(false)
	end
	
	self.tAdventureInfo.nSons = 0
	self.tAdventureInfo.nRollers = 0
	self.tAdventureInfo.nGrinders = 0
end
	
	
function AdventureWhitevale:OnShow(bShow)
	if bShow == true then
		self.wnd:Show(true)
	elseif bShow == false then
		self.wndMain:Show(false)
	end
end

function AdventureWhitevale:OnHide()
	self.wnd:Show(false)
	self.tAdventureInfo.bIsShown = false
end
-----------------------------------------------------------------------------------------------
-- WhitevaleAdventureForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function AdventureWhitevale:OnOK()
	self:OnHide()
end

-- when the Cancel button is clicked
function AdventureWhitevale:OnCancel()
	self:OnHide()
end


-----------------------------------------------------------------------------------------------
-- AdventureWhitevale Instance
-----------------------------------------------------------------------------------------------
local AdventureWhitevaleInst = AdventureWhitevale:new()
AdventureWhitevaleInst:Init()
w()
		xml:AddLine(oArg2)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Macro then
		xml = XmlDoc.new()
		xml:AddLine(oArg1)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Spell then
		Tooltip.GetSpellTooltipForm(self, wndControl, oArg1)
	elseif eType == Tooltip.TooltipGenerateType_PetCommand then
		xml = XmlDoc.new()
		xml:AddLine(oArg2)
		wndControl:SetTooltipDoc(xml)
	end
end

-----------------------------------------------------------
local ActionBarShor