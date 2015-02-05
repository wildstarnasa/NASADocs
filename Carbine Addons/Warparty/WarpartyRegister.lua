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

local crGuildNameLengthError = ApolloColor.new("red")
local crGuildNameLengthGood = ApolloColor.new("ffffffff")
local kstrAlreadyInGuild = Apollo.GetString("Warparty_AlreadyInWarparty")

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function WarpartyRegister:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

function WarpartyRegister:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- WarpartyRegister OnLoad
-----------------------------------------------------------------------------------------------
function WarpartyRegister:OnLoad()
    self.xmlDoc = XmlDoc.CreateFromFile("WarpartyRegister.xml")
    self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function WarpartyRegister:OnDocumentReady()
    if self.xmlDoc == nil then
        return
    end

	Apollo.RegisterEventHandler("GuildResultInterceptResponse", 	"OnGuildResultInterceptResponse", self)
	Apollo.RegisterTimerHandler("ErrorMessageTimer", 				"OnErrorMessageTimer", self)
	Apollo.RegisterEventHandler("GenericEvent_RegisterWarparty", 	"OnWarpartyRegistration", self)
	Apollo.RegisterEventHandler("Event_ShowWarpartyInfo", 			"OnCancel", self)
	Apollo.RegisterEventHandler("LFGWindowHasBeenClosed", 			"OnCancel", self)

    -- load our forms
    self.wndMain = Apollo.LoadForm(self.xmlDoc, 			"WarpartyRegistrationForm", nil, self)
    self.xmlDoc = nil
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
function WarpartyRegister:OnWarpartyRegistration(tPos)
		-- Check to see if the player is already on an warparty of this type
	for key, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr:GetType() == GuildLib.GuildType_WarParty then
			Event_FireGenericEvent("Event_ShowWarpartyInfo")
			return
		end
	end

	self.wndMain:FindChild("WarpartyNameLabel"):SetText(Apollo.GetString("Warparty_NameYourWarparty"))

	self.wndRegister:Enable(true)
	self.wndMain:Show(true)
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
	if nNameLength < 3 or nNameLength > GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildName) then
		self.WndWarpartyNameLimit:SetTextColor(crGuildNameLengthError)
	else
		self.WndWarpartyNameLimit:SetTextColor(crGuildNameLengthGood)
	end

	self.WndWarpartyNameLimit:SetText(String_GetWeaselString(Apollo.GetString("CRB_Progress"), nNameLength, GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildName)))
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
                 <Control Class="Window" LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="0.5" RAnchorOffset="-8" BAnchorPoint="1" BAnchorOffset="-8" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="LblHealth" BGColor="ffffffff" TextColor="ffffffff" TooltipColor=""/>
                        <Control Class="Window" LAnchorPoint="0.5" LAnchorOffset="8" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="1" RAnchorOffset="-8" BAnchorPoint="1" BAnchorOffset="-8" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="LblTier" BGColor="ffffffff" TextColor="ffffffff" TooltipColor=""/>
                    </Control>
                    <Control Class="Window" LAnchorPoint="0" LAnchorOffset="210" TAnchorPoint="0" TAnchorOffset="0" RAnchorPoint="0" RAnchorOffset="280" BAnchorPoint="0" BAnchorOffset="100" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="WndPlug5" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" Sprite="CRB_Basekit:kitBase_HoloBlue_IconBaseStretch" Picture="1" IgnoreMouse="1">
                        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="1" RAnchorOffset="-8" BAnchorPoint="0.5" BAnchorOffset="-8" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="LblHealth" BGColor="ffffffff" TextColor="ffffffff" TooltipColor=""/>
                        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0.5" TAnchorOffset="8" RAnchorPoint="1" RAnchorOffset="-8" BAnchorPoint="1" BAnchorOffset="-8" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="LblTier" BGColor="ffffffff" TextColor="ffffffff" TooltipColor=""/>
                    </Control>
                    <Control Class="Window" LAnchorPoint="0" LAnchorOffset="210" TAnchorPoint="0" TAnchorOffset="105" RAnchorPoint="0" RAnchorOffset="310" BAnchorPoint="0" BAnchorOffset="225" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="WndPlug6" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" Sprite="CRB_Basekit:kitBase_HoloBlue_IconBaseStretch" Picture="1" IgnoreMouse="1">
                        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="1" RAnchorOffset="-8" BAnchorPoint="0.5" BAnchorOffset="-8" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="LblHealth" BGColor="ffffffff" TextColor="ffffffff" TooltipColor=""/>
                        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0.5" TAnchorOffset="8" RAnchorPoint="1" RAnchorOffset="-8" BAnchorPoint="1" BAnchorOffset="-8" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="LblTier" BGColor="ffffffff" TextColor="ffffffff" TooltipColor=""/>
                    </Control>
                    <Control Class="Window" LAnchorPoint="0" LAnchorOffset="105" TAnchorPoint="0" TAnchorOffset="185" RAnchorPoint="0" RAnchorOffset="205" BAnchorPoint="0" BAnchorOffset="245" RelativeToClient="1" Font="Default" Text="" Template="Default" TooltipType="OnCursor" Name="WndPlug7" BGColor="ffffffff" TextColor="ffffffff" TooltipColor="" Sprite="CRB_Basekit:kitBase_HoloBlue_IconBaseStretch" Picture="1" IgnoreMouse="1">
                        <Control Class="Window" LAnchorPoint="0" LAnchorOffset="8" TAnchorPoint="0" TAnchorOffset="8" RAnchorPoint="0.5" RAnchorOffset="-8" BAnchorPoint="1" BAnchorOffset="-8" RelativeToClient="