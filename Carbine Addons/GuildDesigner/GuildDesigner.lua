-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildDesigner
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Money"
require "ChallengesLib"
require "Unit"
require "GameLib"
require "Apollo"
require "PathMission"
require "Quest"
require "Episode"
require "math"
require "string"
require "DialogSys"
require "PublicEvent"
require "PublicEventObjective"
require "CommunicatorLib"
require "Tooltip"
require "GroupLib"
require "PlayerPathLib"
 
-----------------------------------------------------------------------------------------------
-- GuildDesigner Module Definition
-----------------------------------------------------------------------------------------------
local GuildDesigner = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
	
local kstrNoPermissions = Apollo.GetString("GuildDesigner_NotEnoughPermissions")
local knSavedVersion = 0
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function GuildDesigner:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function GuildDesigner:Init()
    Apollo.RegisterAddon(self)
end

function GuildDesigner:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLoc
	
	local tSaved = 
	{
		tWindowLocation = locWindowLocation and locWindowLocation:ToTable() or nil,
		nSavedVersion = knSaveVersion
	}
	
	return tSaved
end

function GuildDesigner:OnRestore(eType, tSavedData)
	if tSavedData.tWindowLocation then
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end
 
-----------------------------------------------------------------------------------------------
-- GuildDesigner OnLoad
-----------------------------------------------------------------------------------------------
function GuildDesigner:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GuildDesigner.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function GuildDesigner:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
	Apollo.RegisterEventHandler("Event_GuildDesignerOn", 	"OnGuildDesignerOn", self)
	Apollo.RegisterEventHandler("GuildResultInterceptResponse", "OnGuildResultInterceptResponse", self)
	Apollo.RegisterEventHandler("GuildStandard", 			"OnGuildDesignUpdated", self)
	Apollo.RegisterEventHandler("GuildInfluenceAndMoney", 	"OnGuildInfluenceAndMoney", self)
	Apollo.RegisterEventHandler("GuildRegistrarClose",		"OnCloseVendorWindow", self)
	
	Apollo.RegisterTimerHandler("GuildDesigner_ModifySuccessfulTimer",	"OnGuildDesigner_ModifySuccessfulTimer", self)
	Apollo.RegisterTimerHandler("GuildDesigner_ModifyErrorTimer", 		"OnGuildDesigner_ModifyErrorTimer", self)	
	--Apollo.RegisterEventHandler("GuildRegistrarOpen", 	"OnGuildDesignerOn", self)	
 	--Apollo.RegisterEventHandler("ToggleGuildDesigner", 	"OnGuildDesignerOn", self) -- TODO: War Parties NYI  
    
    -- load our forms
    self.wndMain 			= Apollo.LoadForm(self.xmlDoc, "GuildDesignerForm", nil, self)
   	self.wndGuildName 		= self.wndMain:FindChild("GuildNameString")
	self.wndRegisterBtn		= self.wndMain:FindChild("RegisterBtn")
	self.wndAlert 			= self.wndMain:FindChild("AlertMessage")
	self.wndHolomark 		= self.wndMain:FindChild("HolomarkContent")
	self.wndHolomarkCostume = self.wndMain:FindChild("HolomarkCostume")
	
	self.tCurrent 			= {}
	self.tNewOptions		= {}
	self.bShowingResult 	= false
	
	self.wndMain:Show(false)
	if self.locSavedWindowLoc then
		self.wndMain:MoveToLocation(self.locSavedWindowLoc)
	end
	
	self:SetDefaults()
end

-----------------------------------------------------------------------------------------------
-- GuildDesigner Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function GuildDesigner:OnGuildDesignerOn()
	self:SetDefaults()
	self:ResetOptions()
	self.wndMain:Show(true) -- show the window
	self.wndMain:ToFront()
end

---------------------------------------------------------------------------------------------------
function GuildDesigner:OnWindowClosed(wndHandler, wndControl)
	-- called after the window is closed by:
	--	self.winMasterCustomizeFrame:Close() or 
	--  hitting ESC
	
	if wndControl ~= wndHandler then
	    return
	end
	
	Event_CancelGuildRegistration()
	
	Sound.Play(Sound.PlayUIWindowClose)
end

function GuildDesigner:OnCloseVendorWindow()
	self.wndMain:Close() -- just close the window which will trigger OnWindowClosed
end

function GuildDesigner:SetDefaults()
	local guildLoaded = nil
	
	self.bShowingResult = false
	
	for key, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr:GetType() == GuildLib.GuildType_Guild then
			guildLoaded = guildCurr
		end
	end

	if guildLoaded == nil then
		self:FormatNoGuild()
		return
	end
	
	self.wndRegisterBtn:SetData(guildLoaded)
	
	self.wndMain:FindChild("GuildRevertBtn"):Enable(false)
	self.wndMain:FindChild("CostAmount"):SetText(0)
	self.wndMain:FindChild("InfluenceAmount"):SetText(guildLoaded:GetInfluence())
	
	self.tCurrent.strName = guildLoaded:GetName()
	self.wndGuildName:SetText(self.tCurrent.strName)
	self.wndGuildName:Enable(false)
	
	self:SetDefaultHolomark()
	
	if guildLoaded:GetMyRank() ~= 1 then -- not a leader. TODO: enum not hardcoded
		self.wndMain:FindChild("GuildPermissionsAlert"):SetText(kstrNoPermissions)
	else
		self.wndMain:FindChild("GuildPermissionsAlert"):SetText("")
	end	
end

function GuildDesigner:FormatNoGuild()
	self.wndGuildName:Enable(true)
	self.wndRegisterBtn:Enable(false)
	self.wndAlert:Show(true)
	self.wndAlert:FindChild("MessageAlertText"):SetText(Apollo.GetString("GuildDesigner_NoGuild"))
	self.wndAlert:FindChild("MessageBodyText"):SetText(Apollo.GetString("GuildDesginer_MustBeInGuild"))
end

function GuildDesigner:ResetOptions()
	if self.tCurrent.strName ~= nil then
		self.wndGuildName:SetText(self.tCurrent.strName)
	else
		self.wndGuildName:SetText("")
	end
	
	self.wndAlert:Show(false)
	self.wndAlert:FindChild("MessageAlertText"):SetText("")
	self.wndAlert:FindChild("MessageBodyText"):SetText("")

	self:UpdateOptions()
end

function GuildDesigner:UpdateOptions()
	local guildOwner = self.wndRegisterBtn:GetData()
	if guildOwner == nil then
		return
	end
	
	local bHasGuildPermissions = false
	
	if guildOwner:GetMyRank() ~= 1 then -- not a leader. TODO: enum not hardcoded
		self.wndMain:FindChild("GuildPermissionsAlert"):SetText(kstrNoPermissions)
	else
		self.wndMain:FindChild("GuildPermissionsAlert"):SetText("")
		bHasGuildPermissions = true
	end		
	
	local bChangeDetected = self:IsHolomarkChanged()
	
	self.wndMain:FindChild("ResetAllBtn"):Enable(bChangeDetected)
	self.wndRegisterBtn:Enable(bChangeDetected and bHasGuildPermissions)

	self:UpdateCost()
end

function GuildDesigner:UpdateCost()
	
	local nCost = 0

	if self:IsHolomarkChanged() then
		nCost = nCost + GuildLib.GetHolomarkModifyCost()
	end
	
	self.wndMain:FindChild("CostAmount"):SetText(nCost)

end

-----------------------------------------------------------------------------------------------
-- Holomark Functions
-----------------------------------------------------------------------------------------------
function GuildDesigner:SetDefaultHolomark()

	self:InitializeHolomarkParts()
	
	local guildOwner = self.wndRegisterBtn:GetData()
	if guildOwner == nil then
		return
	end
	
	self.tCurrent.tHolomark = guildOwner:GetStandard()
	self.tNewOptions.tHolomark = guildOwner:GetStandard()
	
	local tHolomarkPartNames = { "tBackgroundIcon", "tForegroundIcon", "tScanLines" }
	
	for idx, tPartList in ipairs(self.tHolomarkParts) do
		for key, tPart in ipairs(tPartList) do
			if tPart.idBannerPart == self.tCurrent.tHolomark[tHolomarkPartNames[idx]].idPart then
				self.wndMain:FindChild("HolomarkOption."..idx):SetText(tPart.strName)
			end
		end
	end

	--[[
	self.tCurrent.tHolomark = 
	{
		tBackgroundIcon = 
		{
			nPartId = self.tHolomarkParts[1][1]["id"],
			nColorId1 = 2,
			nColorId2 = 2,
			nColorId3 = 2,
		},
		
		tForegroundIcon = 
		{
			nPartId = self.tHolomarkParts[2][1]["id"],
			nColorId1 = 2,
			nColorId2 = 2,
			nColorId3 = 2,
		},
		
		tScanLines = 
		{
			nPartId = self.tHolomarkParts[3][1]["id"],
			nColorId1 = 2,
			nColorId2 = 2,
			nColorId3 = 2,
		},
	}
	
	self.tNewOptions.tHolomark = self.tCurrent.tHolomark
	--]]

	
	self.wndHolomarkCostume:SetCostumeToGuildStandard(self.tCurrent.tHolomark)
end

function GuildDesigner:InitializeHolomarkParts()

	self.tHolomarkPartListItems = {}
	self.wndHolomarkOption = nil
	self.wndHolomarkOptionList = nil
	
	self.tHolomarkParts = {}
	self.tHolomarkParts[1] = GuildLib.GetBannerBackgroundIcons()
	self.tHolomarkParts[2] = GuildLib.GetBannerForegroundIcons()
	self.tHolomarkParts[3] = GuildLib.GetBannerScanLines()
end

function GuildDesigner:OnHolomarkPartCheck1( wndHandler, wndControl, eMouseButton )
	self:FillHolomarkPartList(1)
	self.wndHolomarkOption = self.wndMain:FindChild("HolomarkOption.1")
	self.wndHolomarkOptionList = self.wndMain:FindChild("HolomarkPartWindow.1")
	self.wndHolomarkOptionList:SetData(1)
	self.wndHolomarkOptionList:Show(true)
end

function GuildDesigner:OnHolomarkPartUncheck1( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("HolomarkPartWindow.1"):Show(false)
end

function GuildDesigner:OnHolomarkPartCheck2( wndHandler, wndControl, eMouseButton )
	self:FillHolomarkPartList(2)
	self.wndHolomarkOption = self.wndMain:FindChild("HolomarkOption.2")
	self.wndHolomarkOptionList = self.wndMain:FindChild("HolomarkPartWindow.2")
	self.wndHolomarkOptionList:SetData(2)
	self.wndHolomarkOptionList:Show(true)
end

function GuildDesigner:OnHolomarkPartUncheck2( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("HolomarkPartWindow.2"):Show(false)
end

function GuildDesigner:OnHolomarkPartCheck3( wndHandler, wndControl, eMouseButton )
	self:FillHolomarkPartList(3)
	self.wndHolomarkOption = self.wndMain:FindChild("HolomarkOption.3")
	self.wndHolomarkOptionList = self.wndMain:FindChild("HolomarkPartWindow.3")
	self.wndHolomarkOptionList:SetData(3)
	self.wndHolomarkOptionList:Show(true)
end

function GuildDesigner:OnHolomarkPartUncheck3( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("HolomarkPartWindow.3"):Show(false)
end

function GuildDesigner:FillHolomarkPartList( ePartType )
	local wndList = self.wndMain:FindChild("HolomarkPartList."..(ePartType))
	wndList:DestroyChildren()
	
	local tPartList = self.tHolomarkParts[ePartType]
	if tPartList == nil then
		return
	end
	
	for idx = 1, #tPartList do
		self:AddHolomarkPartItem(wndList, idx, tPartList[idx])
	end
end

function GuildDesigner:AddHolomarkPartItem(wndList, index, tPart)
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "HolomarkPartListItem", wndList, self)
	
	self.tHolomarkPartListItems[index] = wnd
	
	local wndItemBtn = wnd:FindChild("HolomarkPartBtn")
	if wndItemBtn then -- make sure the text wnd exist
	    local strName = tPart.strName
		wndItemBtn:SetText(strName)
		wndItemBtn:SetData(tPart)
	end
	wndList:ArrangeChildrenVert()
end

function GuildDesigner:OnHolomarkPartSelectionClosed( wndHandler, wndControl )
	-- destroy all the wnd inside the list
	for idx,wnd in ipairs(self.tHolomarkPartListItems) do
		wnd:Destroy()
	end
	
	if self.wndHolomarkOptionList:IsVisible() then
        self.wndHolomarkOptionList:Show(false)
	end
	self.wndHolomarkOption:SetCheck(false)

	-- clear the list item array
	self.tHolomarkPartListItems = {}
end

function GuildDesigner:OnHolomarkPartItemSelected(wndHandler, wndControl)
	if not wndControl then 
        return 
    end

	local tPart = wndControl:GetData()
    if tPart ~= nil and self.wndHolomarkOption ~= nil then
		self.wndHolomarkOption:SetText(tPart.strName)
		
		local eType = self.wndHolomarkOptionList:GetData()
		if eType == 1 then
			self.tNewOptions.tHolomark.tBackgroundIcon.idPart = tPart.idBannerPart
		elseif eType == 2 then
			self.tNewOptions.tHolomark.tForegroundIcon.idPart = tPart.idBannerPart
		elseif eType == 3 then
			self.tNewOptions.tHolomark.tScanLines.idPart = tPart.idBannerPart
		end

		self.wndHolomarkCostume:SetCostumeToGuildStandard(self.tNewOptions.tHolomark)
	end
	
	self:UpdateOptions()
	
	self:OnHolomarkPartSelectionClosed(wndHandler, wndControl)
end

function GuildDesigner:IsHolomarkChanged()
	local bChanged = false
	if self.tCurrent.tHolomark.tBackgroundIcon.idPart ~= self.tNewOptions.tHolomark.tBackgroundIcon.idPart or 
	   self.tCurrent.tHolomark.tForegroundIcon.idPart ~= self.tNewOptions.tHolomark.tForegroundIcon.idPart or 
	   self.tCurrent.tHolomark.tScanLines.idPart ~= self.tNewOptions.tHolomark.tScanLines.idPart then
		bChanged = true
	end

	return bChanged
end

-----------------------------------------------------------------------------------------------
-- GuildDesignerForm Functions
-----------------------------------------------------------------------------------------------

-- when the OK button is clicked
function GuildDesigner:OnCommitBtn(wndHandler, wndControl)  -- TODO!!!
	local t = self.tNewOptions
	
	guildCommitted = wndControl:GetData()
	
	if guildCommitted ~= nil then
		
		local arGuildResultsExpected = { GuildLib.GuildResult_VendorOutOfRange, GuildLib.GuildResult_InvalidStandard, GuildLib.GuildResult_CanOnlyModifyRanksBelowYours, 
										 GuildLib.GuildResult_UnableToProcess, GuildLib.GuildResult_InvalidRank, GuildLib.GuildResult_InvalidRankName, 
										 GuildLib.GuildResult_InvalidGuildName, GuildLib.GuildResult_RankLacksSufficientPermissions, GuildLib.GuildResult_InsufficientInfluence, 
										 GuildLib.GuildResult_GuildNameUnavailable }

		Event_FireGenericEvent("GuildResultInterceptRequest", GuildLib.GuildType_Guild, self.wndMain, arGuildResultsExpected )

		guildCommitted:Modify(self.tNewOptions.tHolomark)

		self.wndRegisterBtn:Enable(false)
		self.wndMain:FindChild("ResetAllBtn"):Enable(false)
	end
	
	--NOTE: Requires a server response to progress
end

-- when the Cancel button is clicked
function GuildDesigner:OnCancel(wndHandler, wndControl)
	self:ResetOptions()	
	self.wndMain:Close()
end

function GuildDesigner:OnResetAllBtn(wndHandler, wndControl)
	self:SetDefaults()
end

-- FAILURE ONLY
function GuildDesigner:OnGuildResultInterceptResponse( guildCurr, eGuildType, eResult, wndRegistration, strAlertMessage )
	if eGuildType ~= GuildLib.GuildType_Guild or wndRegistration ~= self.wndMain then
		return
	end

	-- NOTE: success is processed with a different message.

	if not self.wndAlert or not self.wndAlert:IsValid() then
		return
	end

	self.bShowingResult = true
	
	self.wndAlert:FindChild("MessageAlertText"):SetText(Apollo.GetString("GuildDesigner_Whoops"))
	Apollo.CreateTimer("GuildDesigner_ModifyErrorTimer", 3.00, false)			

	self.wndAlert:FindChild("MessageBodyText"):SetText(strAlertMessage)
	self.wndAlert:Show(true)
end

-- SUCCESS ONLY
function GuildDesigner:OnGuildDesignUpdated(guildUpdated) 
	if guildUpdated ~= self.wndRegisterBtn:GetData() then 
		return 
	end
	
	self.bShowingResult = true
	
	self.wndAlert:FindChild("MessageAlertText"):SetText(Apollo.GetString("GuildDesigner_Success"))
	Apollo.CreateTimer("GuildDesigner_ModifySuccessfulTimer", 3.00, false)

	self.wndAlert:FindChild("MessageBodyText"):SetText(Apollo.GetString("GuildDesigner_Updated"))
	self.wndAlert:Show(true)
end

function GuildDesigner:OnGuildDesigner_ModifySuccessfulTimer()
	self.bShowingResult = false
	self.wndAlert:Show(false)
	self:SetDefaults()
end

function GuildDesigner:OnGuildDesigner_ModifyErrorTimer()
	self.bShowingResult = false
	self.wndAlert:Show(false)
	self.wndMain:FindChild("ResetAllBtn"):Enable(true) -- something had to have been changed
	self.wndRegisterBtn:Enable(true) -- safe to assume since it was clicked once
end

function GuildDesigner:OnGuildInfluenceAndMoney(guildCurr, monInfluence, monCash)
	if guildCurr:GetType() == GuildLib.GuildType_Guild then
		self.wndMain:FindChild("InfluenceAmount"):SetText(guildCurr:GetInfluence())
	end
end

function GuildDesigner:OnNameChanged(wndHandler, wndControl, strName)
	self:UpdateOptions()
end

-----------------------------------------------------------------------------------------------
-- GuildDesigner Instance
-----------------------------------------------------------------------------------------------
local GuildDesignerInst = GuildDesigner:new()
GuildDesignerInst:Init()


