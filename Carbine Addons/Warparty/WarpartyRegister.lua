-----------------------------------------------------------------------------------------------
-- Client Lua Script for Warparty Registration
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "GuildLib"
require "Unit"

-----------------------------------------------------------------------------------------------
-- WarpartyRegister Module Definition
-----------------------------------------------------------------------------------------------
local WarpartyRegister = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local kcrDefaultText = CColor.new(135/255, 135/255, 135/255, 1.0)
local kcrHighlightedText = CColor.new(0, 1.0, 1.0, 1.0)

local ktResultString =
{
	[GuildLib.GuildResult_Success] 				= Apollo.GetString("Warparty_ResultSuccess"),
	[GuildLib.GuildResult_AtMaxGuildCount] 		= Apollo.GetString("Warparty_OnlyOneWarparty"),
	[GuildLib.GuildResult_InvalidGuildName] 	= Apollo.GetString("Warparty_InvalidName"),
	[GuildLib.GuildResult_GuildNameUnavailable] = Apollo.GetString("Warparty_NameUnavailable"),	-- Note - there are more reasons why it could be unavailble besides it being in use.
	[GuildLib.GuildResult_NotHighEnoughLevel] 	= Apollo.GetString("Warparty_InsufficientLevel"),
}

local knMaxGuildRankName = 16
local crGuildNameLengthError = ApolloColor.new("red")
local crGuildNameLengthGood = ApolloColor.new("ffffffff")
local kstrAlreadyInGuild = Apollo.GetString("Warparty_AlreadyInWarparty")

local knSaveVersion = 1

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function WarpartyRegister:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here

    return o
end

function WarpartyRegister:Init()
    Apollo.RegisterAddon(self)
end

function WarpartyRegister:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local tSave = 
	{
		tOffsets = self.wndMain and {self.wndMain:GetAnchorOffsets()} or self.SavedOffsets,
		nSaveVersion = knSaveVersion,
	}
	
	return tSave
end

function WarpartyRegister:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	if self.wndMain and tSavedData.tOffsets then
		self.wndMain:SetAnchorOffsets(unpack(tSavedData.tOffsets))
	end
end


-----------------------------------------------------------------------------------------------
-- WarpartyRegister OnLoad
-----------------------------------------------------------------------------------------------
function WarpartyRegister:OnLoad()
	Apollo.RegisterEventHandler("GuildResultInterceptResponse", 	"OnGuildResultInterceptResponse", self)
	Apollo.RegisterTimerHandler("ErrorMessageTimer", 				"OnErrorMessageTimer", self)
   --Apollo.RegisterSlashCommand("warparty", 						"OnWarpartyRegistration", self)
	Apollo.RegisterEventHandler("GenericEvent_RegisterWarparty", 	"OnWarpartyRegistration", self)
	Apollo.RegisterEventHandler("Event_ShowWarpartyInfo", 			"OnCancel", self)
	Apollo.RegisterEventHandler("LFGWindowHasBeenClosed", 			"OnCancel", self)

    -- load our forms
    self.wndMain = Apollo.LoadForm("WarpartyRegister.xml", 			"WarpartyRegistrationForm", nil, self)
    self.wndMain:Show(false)

	self.wndWarpartyName = self.wndMain:FindChild("WarpartyNameString")
	self.WndWarpartyNameLimit = self.wndMain:FindChild("WarpartyNameLimit")
	self.wndRegister = self.wndMain:FindChild("RegisterBtn")

	self.wndAlert = self.wndMain:FindChild("AlertMessage")

	self.tCreate = {}
	self.tCreate.strName = ""

	self:ResetOptions()
end


-----------------------------------------------------------------------------------------------
-- WarpartyRegister Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

--function WarpartyRegister:OnWarpartyRegistration(command, warpartySize)
function WarpartyRegister:OnWarpartyRegistration(tPos)
		-- Check to see if the player is already on an warparty of this type
	for key, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr:GetType() == GuildLib.GuildType_WarParty then
			Event_FireGenericEvent("Event_ShowWarpartyInfo")
			return
		end
	end

	self.wndMain:FindChild("WarpartyNameLabel"):SetText(Apollo.GetString("Warparty_NameYourWarparty"))

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	if tPos ~= nil then
		if tPos.bDrawOnLeft == true then
			--self.wndMain:Move(tPos.nX - (nRight - nLeft) + 2, tPos.nY + 3, nRight - nLeft, nBottom - nTop)
		else
			--self.wndMain:Move(tPos.nX - 8, tPos.nY + 3, nRight - nLeft, nBottom - nTop)
		end
	end

	self.wndRegister:Enable(true)
	self.wndMain:Show(true) -- show the window
	self.wndMain:ToFront()
	self:Validate()
end

function WarpartyRegister:ResetOptions()
	self.tCreate.strName = ""
	self.wndAlert:Show(false)
	self.wndAlert:FindChild("MessageAlertText"):SetText("")
	self.wndAlert:FindChild("MessageBodyText"):SetText("")
	self.wndWarpartyName:SetText("")
	self:HelperClearFocus()
	self:Validate()
end

function WarpartyRegister:OnNameChanging(wndHandler, wndControl)
	self.tCreate.strName = self.wndWarpartyName:GetText()
	self:Validate()
end

function WarpartyRegister:Validate()
	local bIsTextValid = GameLib.IsTextValid(self.tCreate.strName, GameLib.CodeEnumUserText.GuildName, GameLib.CodeEnumUserTextFilterClass.Strict)
	local bValid = self:HelperCheckForEmptyString(self.tCreate.strName) and bIsTextValid

	self.wndRegister:Enable(bValid)

	local nNameLength = string.len(self.tCreate.strName or "")
	if nNameLength < 1 or nNameLength > knMaxGuildRankName then
		self.WndWarpartyNameLimit:SetTextColor(crGuildNameLengthError)
	else
		self.WndWarpartyNameLimit:SetTextColor(crGuildNameLengthGood)
	end

	self.WndWarpartyNameLimit:SetText(String_GetWeaselString(Apollo.GetString("CRB_Progress"), nNameLength, knMaxGuildRankName))
end

function WarpartyRegister:HelperCheckForEmptyString(strText) -- make sure there's a valid string
	local strFirstChar
	local bHasText = false

	strFirstChar = string.find(strText, "%S")

	bHasText = strFirstChar ~= nil and string.len(strFirstChar) > 0
	return bHasText
end

function WarpartyRegister:HelperClearFocus(wndHandler, wndControl)
	self.wndWarpartyName:ClearFocus()
end

-----------------------------------------------------------------------------------------------
-- WarpartyRegistrationForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function WarpartyRegister:OnRegisterBtn(wndHandler, wndControl)
	local tGuildInfo = self.tCreate

	local arGuldResultsExpected = { GuildLib.GuildResult_Success,  GuildLib.GuildResult_AtMaxGuildCount, GuildLib.GuildResult_InvalidGuildName,
									 GuildLib.GuildResult_GuildNameUnavailable, GuildLib.GuildResult_NotEnoughRenown, GuildLib.GuildResult_NotEnoughCredits,
									 GuildLib.GuildResult_InsufficientInfluence, GuildLib.GuildResult_NotHighEnoughLevel, GuildLib.GuildResult_YouJoined,
									 GuildLib.GuildResult_YouCreated, GuildLib.GuildResult_MaxArenaTeamCount, GuildLib.GuildResult_MaxWarPartyCount,
									 GuildLib.GuildResult_AtMaxCircleCount, GuildLib.GuildResult_VendorOutOfRange, GuildLib.GuildResult_CannotCreateWhileInQueue }

	Event_FireGenericEvent("GuildResultInterceptRequest", GuildLib.GuildType_WarParty, self.wndMain, arGuldResultsExpected )

	GuildLib.Create(tGuildInfo.strName, GuildLib.GuildType_WarParty)
	self:HelperClearFocus()
	self.wndRegister:Enable(false)
	--NOTE: Requires a server response to progress
end

-- when the Cancel button is clicked
function WarpartyRegister:OnCancel(wndHandler, wndControl)
	self.wndMain:Show(false) -- hide the window
	self:HelperClearFocus()
	self:ResetOptions()
end

function WarpartyRegister:OnGuildResultInterceptResponse( guildCurr, eGuildType, eResult, wndRegistration, strAlertMessage )

	if eGuildType ~= GuildLib.GuildType_WarParty or wndRegistration ~= self.wndMain then
		return
	end

	if eResult == GuildLib.GuildResult_YouCreated or eResult == GuildLib.GuildResult_YouJoined then
		Event_FireGenericEvent("Event_ShowWarpartyInfo")
		self:OnCancel()
	end

	self.wndAlert:FindChild("MessageAlertText"):SetText(Apollo.GetString("Warparty_Whoops"))
	Apollo.CreateTimer("ErrorMessageTimer", 3.00, false)
	self.wndAlert:FindChild("MessageBodyText"):SetText(strAlertMessage)
	self.wndAlert:Show(true)
end

function WarpartyRegister:OnErrorMessageTimer()
	self.wndAlert:Show(false)
	self.wndRegister:Enable(true) -- safe to assume since it was clicked once
end

-----------------------------------------------------------------------------------------------
-- WarpartyRegister Instance
-----------------------------------------------------------------------------------------------
local WarpartyRegisterInst = WarpartyRegister:new()
WarpartyRegisterInst:Init()
