-----------------------------------------------------------------------------------------------
-- Client Lua Script for TaxiMap
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Unit"
require "GameLib"
require "Tooltip"
require "XmlDoc"
require "PlayerPathLib"
require "HexGroups"
 
-----------------------------------------------------------------------------------------------
-- TaxiMap Module Definition
-----------------------------------------------------------------------------------------------
local TaxiMap = {} 

local knSaveVersion = 1
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function TaxiMap:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.unitTaxi = nil
	o.nTaxiUnderCursor = 0
	o.tTaxiObjects = {}
	o.tTaxiNodes = {}
	o.tTaxiRoutes = {}

    return o
end

function TaxiMap:Init()
    Apollo.RegisterAddon(self)
end
 
function TaxiMap:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	local locMapLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedMapLocation
	local locPromptLocation = self.wndPrompt and self.wndPrompt:GetLocation() or self.locSavedPromptLocation
	
	local tSave =
	{
		tMapLocation 	= locMapLocation and locMapLocation:ToTable() or nil,
		tPromptLocation = locPromptLocation and locPromptLocation:ToTable() or nil,
		nVersion 		= knSaveVersion,
	}
	
	return tSave
end
 
function TaxiMap:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nVersion ~= knSaveVersion then
		return
	end
	
	if tSavedData.tMapLocation then
		self.locSavedMapLocation = WindowLocation.new(tSavedData.tMapLocation)
	end
	
	if tSavedData.tPromptLocation then
		self.locSavedPromptLocation = WindowLocation.new(tSavedData.tPromptLocation)
	end
end
 
-----------------------------------------------------------------------------------------------
-- TaxiMap OnLoad
-----------------------------------------------------------------------------------------------
function TaxiMap:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("TaxiMap.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function TaxiMap:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("FlightPathUpdate", 		"OnFlightPathUpdate", self)
	Apollo.RegisterEventHandler("InvokeTaxiWindow", 		"OnInvokeTaxiWindow", self)
	Apollo.RegisterEventHandler("InvokeShuttlePrompt", 		"OnInvokeShuttlePrompt", self)		
	Apollo.RegisterEventHandler("CloseVendorWindow", 		"OnCloseVendorWindow", self)
	Apollo.RegisterEventHandler("TaxiWindowClose",			"OnCloseVendorWindow", self)
	Apollo.RegisterTimerHandler("Taxi_MessageDisplayTimer",	"OnMessageDisplayTimer", self)
    
    -- load our forms
    self.wndMain 	= Apollo.LoadForm(self.xmlDoc, "TaxiMapForm", nil, self)
	if self.locSavedMapLocation then
		self.wndMain:MoveToLocation(self.locSavedMapLocation)
	end
		
	self.wndPrompt	= Apollo.LoadForm(self.xmlDoc, "ShuttlePrompt", nil, self)
	if self.locSavedPromptLocation then
		self.wndPrompt:MoveToLocation(self.locSavedPromptLocation)
	end
	
	self.xmlDoc = nil
	self.wndMap 	= self.wndMain:FindChild("WorldMap")
	self.wndTitle 	= self.wndMain:FindChild("Title")
	self.wndTaxiMap = self.wndMain:FindChild("WorldMap")
	self.wndMessage	= self.wndMain:FindChild("UpdateMessage")
	
	self.tZoneInfo = nil
	
	self.wndMain:Show(false, true)
	self.wndPrompt:Show(false, true)
	self.wndMessage:Show(false, true)
end


-----------------------------------------------------------------------------------------------
-- TaxiMap Functions
-----------------------------------------------------------------------------------------------

function TaxiMap:OnInvokeTaxiWindow(unitTaxi, bSettlerTaxi)
	if self.wndMain:IsShown() then
		return
	end

	if unitTaxi == nil then
		return
	end

	self.unitTaxi = unitTaxi
	self.bSettlerTaxi = bSettlerTaxi
	
	local tZoneInfo = GameLib.GetCurrentZoneMap()
	if tZoneInfo ~= nil then 
		self.tZoneInfo = tZoneInfo
	else	
		return
	end	
	
	self:PopulateTaxiMap()
	self.wndMain:Show(true)
end

-----------------------------------------------------------------------------------------------

function TaxiMap:OnInvokeShuttlePrompt(unitTaxi)
	if self.wndPrompt:IsShown() then
		return
	end

	if unitTaxi == nil then
		return
	end

	self.unitTaxi = unitTaxi
	
	local strPrompt = String_GetWeaselString(Apollo.GetString("TaxiMap_ShuttleConfirmation"), unitTaxi:GetTransferDestination())
	self.wndPrompt:FindChild("Title"):SetText(strPrompt)
	
	self.wndPrompt:Show(true)
end

-----------------------------------------------------------------------------------------------
function TaxiMap:OnFlightPathUpdate()
	if not self.wndMain:IsShown() then
		return
	end

	if self.unitTaxi == nil then
		return
	end

	self:PopulateTaxiMap()
end

-----------------------------------------------------------------------------------------------
function TaxiMap:PopulateTaxiMap()
	self.wndTaxiMap:RemoveAllLines()
	self.wndTaxiMap:RemoveAllObjects()

	local tNodes = self.unitTaxi:GetFlightPaths()

	if tNodes == nil or self.tZoneInfo == nil then
		return
	end
	
	self.tTaxiObjects = {}
	self.tTaxiRoutes = {}
	self.tTaxiNodes = {}
	self.nTaxiUnderCursor = 0
	
	self.wndMap:SetZone(self.tZoneInfo.id)
	local nCurrentContinent = self.wndMap:GetContinentInfo(self.tZoneInfo.continentId)	
	
	if self.bSettlerTaxi == false and nCurrentContinent ~= nil and nCurrentContinent.bCanDisplay == true then
		self.wndMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Continent)
		self.wndMap:SetMinDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Continent)
		self.wndMap:SetMaxDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Continent)
	else
		self.wndMap:SetDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Scaled)
		self.wndMap:SetMinDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Scaled)
		self.wndMap:SetMaxDisplayMode(ZoneMapWindow.CodeEnumDisplayMode.Scaled)
	end
	
	local tUnlockedInfo =
	{
		strIcon = "IconSprites:Icon_MapNode_Map_Taxi",
		crObject = CColor.new(1, 1, 1, 1),
		strIconEdge = "IconSprites:Icon_MapNode_Map_Taxi",
		crEdge = CColor.new(1, 1, 1, 1),
	}
	
	local tLockedInfo =
	{
		strIcon = "IconSprites:Icon_MapNode_Map_Taxi_Undiscovered",
		crObject = CColor.new(1, 1, 1, 1),
		strIconEdge = "IconSprites:Icon_MapNode_Map_Taxi_Undiscovered",
		crEdge = CColor.new(1, 1, 1, 1),
	}

	if not self.eOverlayType then
		self.eOverlayType = self.wndTaxiMap:CreateOverlayType()
	end

	for idx, tTaxi in ipairs(tNodes) do
		if tTaxi.eType == Unit.CodeEnumFlightPathType.Local then
			local idObject = self.wndTaxiMap:AddObject(self.eOverlayType, tTaxi.tLocation, tTaxi.strName, (tTaxi.bUnlocked and tUnlockedInfo or tLockedInfo), {bNeverShowOnEdge = true, bFixedSizeLarge = true})
			self.tTaxiObjects[idObject] = tTaxi
			self.tTaxiNodes[tTaxi.idNode] = tTaxi
		end
	end
	
	self.wndTaxiMap:SetDisplayMode(3)
end

-----------------------------------------------------------------------------------------------
-- TaxiMapForm Functions
-----------------------------------------------------------------------------------------------

function TaxiMap:OnWindowClosed()
	self.tTaxiObjects = {}
	self.tTaxiNodes = {}
	self.tTaxiRoutes = {}
	self.nTaxiUnderCursor = 0
	Event_CancelTaxiVendor()
end

-----------------------------------------------------------------------------------------------
function TaxiMap:OnPromptWindowClosed()
	Event_CancelTaxiVendor()
end

-----------------------------------------------------------------------------------------------
-- when the Cancel button is clicked
function TaxiMap:OnCancel(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	-- just close the window which will trigger OnWindowClosed
	self.wndMain:Close()
end

-----------------------------------------------------------------------------------------------
-- when the No button is clicked
function TaxiMap:OnNo(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end

	-- just close the window which will trigger OnWindowClosed
	self.wndPrompt:Close()
end

-----------------------------------------------------------------------------------------------
-- when the Yes button is clicked
function TaxiMap:OnYes(wndHandler, wndControl)
	if wndHandler:GetId() ~= wndControl:GetId() then
		return
	end
	
	self.unitTaxi:TakeShuttle()

	-- just close the window which will trigger OnWindowClosed
	self.wndPrompt:Close()
end

-----------------------------------------------------------------------------------------------
function TaxiMap:OnCloseVendorWindow()
	if self.wndMain:IsShown() then
		self.wndMain:Close()
	end
	
	if self.wndPrompt:IsShown() then
		self.wndPrompt:Close()
	end
end

-----------------------------------------------------------------------------------------------
function TaxiMap:OnTaxiMapButtonDown(wndHandler, wndControl, eButton, nX, nY, bDoubleClick)
	local tPos = self.wndTaxiMap:WindowPointToClientPoint(nX, nY)
	
	local tObjects = self.wndTaxiMap:GetObjectsAt(tPos.x, tPos.y)
	for key, tObject in pairs(tObjects) do
		local tTaxi = self.tTaxiObjects[tObject.id]
		if tTaxi.bUnlocked then
			if self.unitTaxi:GetFlightPathToPoint(tTaxi.idNode) then
				self.unitTaxi:PurchaseFlightPath(tTaxi.idNode)
			else
				self.wndMessage:FindChild("MessageText"):SetText(Apollo.GetString("TaxiMap_CantRoute"))
				self.wndMessage:Show(true)
				Apollo.StopTimer("Taxi_MessageDisplayTimer")
				Apollo.CreateTimer("Taxi_MessageDisplayTimer", 4.000, false)
			end
		else
			self.wndMessage:FindChild("MessageText"):SetText(Apollo.GetString("TaxiMap_NotUnlocked"))
			self.wndMessage:Show(true)
			Apollo.StopTimer("Taxi_MessageDisplayTimer")
			Apollo.CreateTimer("Taxi_MessageDisplayTimer", 4.000, false)
		end
	end
		
	return true
end

-----------------------------------------------------------------------------------------------
function TaxiMap:OnMouseMove(wndHandler, wndControl, nX, nY)
	self:OnGenerateTooltip(wndHandler, wndControl, Tooltip.TooltipGenerateType_Default, nX, nY)
end

-----------------------------------------------------------------------------------------------
function TaxiMap:OnGenerateTooltip(wndHandler, wndControl, eType, nX, nY)
	local strTooltipString = ""
	local strBlankLine = string.format("<P Font=\"%s\" TextColor=\"%s\">" .. ":" .. "</P>", "CRB_Pixel", "00ffffff")

	if eType == Tooltip.TooltipGenerateType_Default then
		local tPos = self.wndTaxiMap:WindowPointToClientPoint(nX, nY)
		
		local tObjects = self.wndTaxiMap:GetObjectsAt(tPos.x, tPos.y)

		for key, tObject in pairs(tObjects) do
			local tTaxi = self.tTaxiObjects[tObject.id]
			
			strTooltipString = string.format("<P Font=\"%s\" TextColor=\"%s\">" .. tObject.strName .. "</P>", "CRB_InterfaceMedium", "ffffffff")
			
			if tTaxi.bUnlocked then
				local tPath = self.tTaxiRoutes[tTaxi.idNode]
				if tPath == nil then
					tPath = self.unitTaxi:GetFlightPathToPoint(tTaxi.idNode)
					if tPath ~= nil then
						self.tTaxiRoutes[tTaxi.idNode] = tPath
					end
				end
				
				if tPath ~= nil then
					if self.nTaxiUnderCursor ~= tTaxi.idNode then
						self.nTaxiUnderCursor = tTaxi.idNode
						self.wndTaxiMap:RemoveAllLines()
						local nPrev = 0
						for idx, idNode in ipairs(tPath.tRoute) do
							if nPrev ~= 0 then
								self.wndTaxiMap:AddLine(self.tTaxiNodes[nPrev].tLocation, self.tTaxiNodes[idNode].tLocation, 5.0, CColor.new(1, 1, 1, 1), "", "")
							end
							nPrev = idNode
						end
					end
					
					local nPlatinum = math.floor(tPath.tPriceInfo.nAmount1 / (1000000))
					local nRemainder = tPath.tPriceInfo.nAmount1 % (1000000)
					local nGold = math.floor(nRemainder / (10000))
					nRemainder = nRemainder % (10000)
					local nSilver = math.floor(nRemainder / 100)
					local nCopper = math.floor(nRemainder % 100)		
					
					if nPlatinum >= 1 then
						local strPlatinumLine = string.format("<P Font=\"%s\" TextColor=\"%s\">%s</P>", "CRB_InterfaceSmall", "ffdbd7d2", String_GetWeaselString(Apollo.GetString("CRB_Platinum"), nPlatinum))
						strTooltipString = strTooltipString .. strPlatinumLine
					end
					
					if nGold >= 1 then
						local strGoldLine = string.format("<P Font=\"%s\" TextColor=\"%s\">%s</P>", "CRB_InterfaceSmall", "ffffd700", String_GetWeaselString(Apollo.GetString("CRB_Gold"), nGold))
						strTooltipString = strTooltipString .. strGoldLine
					end
					
					if nSilver >= 1 then
						local strSilverLine = string.format("<P Font=\"%s\" TextColor=\"%s\">%s</P>", "CRB_InterfaceSmall", "ffc0c0c0", String_GetWeaselString(Apollo.GetString("CRB_Silver"), nSilver))
						strTooltipString = strTooltipString .. strSilverLine
					end
					
					if nCopper >= 1 then
						local strCopperLine = string.format("<P Font=\"%s\" TextColor=\"%s\">%s</P>", "CRB_InterfaceSmall", "ffcd7f32", String_GetWeaselString(Apollo.GetString("CRB_Copper"), nCopper))
						strTooltipString = strTooltipString .. strCopperLine
					end
				end
			else
				strTooltipString = strTooltipString .. string.format("<P Font=\"%s\" TextColor=\"%s\">" .. Apollo.GetString("TaxiMap_NotUnlocked") .. "</P>", "CRB_InterfaceSmall", "UI_TextHoloTitle")
			end
		end
	end

	wndControl:SetTooltipType(Window.TPT_OnCursor)
	wndControl:SetTooltip(strTooltipString)
end

-----------------------------------------------------------------------------------------------
function TaxiMap:OnMessageDisplayTimer()
	self.wndMessage:Show(false)
end

-----------------------------------------------------------------------------------------------
-- TaxiMap Instance
-----------------------------------------------------------------------------------------------
local TaxiMapInst = TaxiMap:new()
TaxiMapInst:Init()
