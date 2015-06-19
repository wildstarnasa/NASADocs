-----------------------------------------------------------------------------------------------
-- Client Lua Script for Arena Team Registration
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "GameLib"
require "GuildLib"
require "Unit"
 
-----------------------------------------------------------------------------------------------
-- ArenaTeamRegister Module Definition
-----------------------------------------------------------------------------------------------
local ArenaTeamRegister = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local kcrDefaultText = CColor.new(135/255, 135/255, 135/255, 1.0)
local kcrHighlightedText = CColor.new(0, 1.0, 1.0, 1.0)
local kstrAlreadyInGuild = Apollo.GetString("ArenaRegister_AlreadyInGuild")
local knMinGuildNameLength = 3
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function ArenaTeamRegister:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function ArenaTeamRegister:Init()
    Apollo.RegisterAddon(self)
end
-----------------------------------------------------------------------------------------------
-- ArenaTeamRegister OnLoad
-----------------------------------------------------------------------------------------------
function ArenaTeamRegister:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ArenaTeamRegister.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function ArenaTeamRegister:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("WindowManagementReady", 		"OnWindowManagementReady", self)
	
	Apollo.RegisterEventHandler("GuildResultInterceptResponse", "OnGuildResultInterceptResponse", self)
 	Apollo.RegisterEventHandler("GenericEvent_RegisterArenaTeam", "OnArenaTeamRegistration", self)
	Apollo.RegisterEventHandler("Event_ShowArenaInfo", "OnCancel", self)
	Apollo.RegisterEventHandler("LFGWindowHasBeenClosed", "OnCancel", self)
	
	self.timerErrorMessage = ApolloTimer.Create(3.0, false, "OnErrorMessageTimer", self)
	self.timerErrorMessage:Stop()
    
    -- load our forms
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "ArenaTeamRegistrationForm", nil, self)
    self.wndMain:Show(false)
	self.xmlDoc = nil
	
	self.wndArenaTeamName = self.wndMain:FindChild("RegistrationContent:ArenaTeamNameString")
	self.wndRegister = self.wndMain:FindChild("RegisterBtn")
	
	self.wndAlert = self.wndMain:FindChild("AlertMessage")
	self.wndArenaTeamName:SetMaxTextLength(GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildName))
	
	self.tPos = nil

	self.tCreate = {}
	self.tCreate.strName = ""
	self.tCreate.eGuildType = nil
	self.tCreate.iColor = 1

	self:ResetOptions()
end

function ArenaTeamRegister:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("MatchMaker_Arenas"), nSaveVersion=2})
end

-----------------------------------------------------------------------------------------------
-- ArenaTeamRegister Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

--function ArenaTeamRegister:OnArenaTeamRegistration(command, teamSize)
function ArenaTeamRegister:OnArenaTeamRegistration(eTeamSize, tPos)
	
	self.tCreate.eGuildType = eTeamSize
	
	local strSize = Apollo.GetString("ArenaRoster_2v2")
	if eTeamSize == GuildLib.GuildType_ArenaTeam_3v3 then
		strSize = Apollo.GetString("ArenaRoster_3v3") 
	elseif eTeamSize == GuildLib.GuildType_ArenaTeam_5v5 then
		strSize = Apollo.GetString("ArenaRoster_5v5")
	end	
	
	self.wndMain:FindChild("ArenaTeamNameLabel"):SetText(String_GetWeaselString(Apollo.GetString("ArenaRegister_NameHeader"), strSize))

	-- Check to see if the player is already on an arena team of this type
	--local guildNew = nil
	
	for key, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr:GetType() == self.tCreate.eGuildType then
			Event_FireGenericEvent("Event_ShowArenaInfo", self.tCreate.eGuildType, self.tPos)
			return
		end
	end
	
	-- Set the window's position
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	if tPos ~= nil then
		self.tPos = tPos
		
		if tPos.bDrawOnLeft == true then
			--self.wndMain:Move(tPos.nX - (nRight - nLeft) + 2, tPos.nY + 3, nRight - nLeft, nBottom - nTop)
		else
			--self.wndMain:Move(tPos.nX - 8, tPos.nY + 3, nRight - nLeft, nBottom - nTop)
		end
	end

	self.wndRegister:Enable(false)
	self.wndMain:Invoke() -- show the window
	self.wndMain:ToFront()
end

function ArenaTeamRegister:ResetOptions()
	-- Reset the data for the next time the player attempts to create a team
	self.wndAlert:Close()
	self.wndAlert:FindChild("MessageAlertText"):SetText("")
	self.wndAlert:FindChild("MessageBodyText"):SetText("")	
	self.wndArenaTeamName:SetText("")
	self.tCreate.strName = ""
	self:HelperClearFocus()
	self.wndMain:FindChild("RegistrationContent:ValidAlert"):Show(false)
	
	self:OnNameChanging(self.wndArenaTeamName, self.wndArenaTeamName)
end

function ArenaTeamRegister:OnNameChanging(wndHandler, wndControl)
	local strInput = self.wndArenaTeamName:GetText() or ""
	local wndLimit = self.wndMain:FindChild("RegistrationContent:Limit")
			
	if wndLimit ~= nil then
		local eProfanityFilter = GameLib.CodeEnumUserTextFilterClass.Strict
		local bIsValid = GameLib.IsTextValid(strInput, GameLib.CodeEnumUserText.GuildName, eProfanityFilter)
	
		local nNameLength = string.len(strInput)
		local nMaxLength = GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildName)
		
		wndLimit:SetText(String_GetWeaselString(Apollo.GetString("CRB_Progress"), nNameLength, nMaxLength))

		if nNameLength < knMinGuildNameLength or nNameLength > nMaxLength then
			wndLimit:SetTextColor(ApolloColor.new("AlertOrangeYellow"))
		else
			wndLimit:SetTextColor(ApolloColor.new("UI_TextHoloBodyCyan"))
		end

		self.wndRegister:Enable(bIsValid)
		self.wndMain:FindChild("RegistrationContent:ValidAlert"):Show(not bIsValid)
		self.tCreate.strName = bIsValid and strInput or ""
	end
	
end

function ArenaTeamRegister:HelperClearFocus(wndHandler, wndControl)
	self.wndArenaTeamName:ClearFocus()
end

-----------------------------------------------------------------------------------------------
-- ArenaTeamRegistrationForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function ArenaTeamRegister:OnRegisterBtn(wndHandler, wndControl)
	local tGuildInfo = self.tCreate
	
	local arGuldResultsExpected = { GuildLib.GuildResult_Success,  GuildLib.GuildResult_AtMaxGuildCount, GuildLib.GuildResult_InvalidGuildName, 
									 GuildLib.GuildResult_GuildNameUnavailable, GuildLib.GuildResult_NotEnoughRenown, GuildLib.GuildResult_NotEnoughCredits,
									 GuildLib.GuildResult_InsufficientInfluence, GuildLib.GuildResult_NotHighEnoughLevel, GuildLib.GuildResult_YouJoined,
									 GuildLib.GuildResult_YouCreated, GuildLib.GuildResult_MaxArenaTeamCount, GuildLib.GuildResult_MaxWarPartyCount,
									 GuildLib.GuildResult_AtMaxCircleCount, GuildLib.GuildResult_VendorOutOfRange }

	Event_FireGenericEvent("GuildResultInterceptRequest", tGuildInfo.eGuildType, self.wndMain, arGuldResultsExpected )

	GuildLib.Create(tGuildInfo.strName, tGuildInfo.eGuildType)
	self:HelperClearFocus()
	self.wndRegister:Enable(false)
	--NOTE: Requires a server response to progress
end

-- when the Cancel button is clicked
function ArenaTeamRegister:OnCancel(wndHandler, wndControl)
	Event_FireGenericEvent("GuildRegistrationWindowChange", self.tCreate.eGuildType, nil )
	self.wndMain:Close() -- hide the window
	self.wndAlert:Show(false)
	self:HelperClearFocus()	
	self:ResetOptions()	
end

function ArenaTeamRegister:OnGuildResultInterceptResponse( guildCurr, eGuildType, eResult, wndRegistration, strAlertMessage )
	if eGuildType ~= self.tCreate.eGuildType or wndRegistration ~= self.wndMain then
		return
	end	

	if eResult == GuildLib.GuildResult_Success or eResult == GuildLib.GuildResult_YouCreated or eResult == GuildLib.GuildResult_YouJoined then	
		Event_FireGenericEvent("Event_ShowArenaInfo", self.tCreate.eGuildType, self.tPos)
		self.wndMain:Close()
	else
		self.wndAlert:FindChild("MessageAlertText"):SetText(Apollo.GetString("ArenaRegister_Woops"))
		self.timerErrorMessage:Start()
		self.wndAlert:FindChild("MessageBodyText"):SetText(strAlertMessage)
		self.wndAlert:Invoke()
	end
end

function ArenaTeamRegister:OnErrorMessageTimer()
	self.wndAlert:Close()
	self.wndRegister:Enable(true) -- safe to assume since it was clicked once
end

-----------------------------------------------------------------------------------------------
-- ArenaTeamRegister Instance
-----------------------------------------------------------------------------------------------
local ArenaTeamRegisterInst = ArenaTeamRegister:new()
ArenaTeamRegister:Init()
