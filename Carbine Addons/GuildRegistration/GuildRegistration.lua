-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildRegistration
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Money"
require "ChallengesLib"
require "Unit"
require "GameLib"
require "GuildLib"
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

local GuildRegistration = {}

local kcrDefaultText = CColor.new(135/255, 135/255, 135/255, 1.0)
local kcrHighlightedText = CColor.new(0, 1.0, 1.0, 1.0)
local eProfanityFilter = GameLib.CodeEnumUserTextFilterClass.Strict

local ktstrGuildTypes =
{
	[GuildLib.GuildType_Guild]			= Apollo.GetString("Guild_GuildTypeGuild"),
	[GuildLib.GuildType_Circle]			= Apollo.GetString("Guild_GuildTypeCircle"),
	[GuildLib.GuildType_ArenaTeam_2v2]	= Apollo.GetString("Guild_GuildTypeArena"),
	[GuildLib.GuildType_ArenaTeam_3v3]	= Apollo.GetString("Guild_GuildTypeArena"),
	[GuildLib.GuildType_ArenaTeam_5v5]	= Apollo.GetString("Guild_GuildTypeArena"),
	[GuildLib.GuildType_WarParty]		= Apollo.GetString("Guild_GuildTypeWarparty"),
}

local kstrDefaultOption =
{
	Apollo.GetString("CRB_Guild_Master"),
	Apollo.GetString("CRB_Guild_Council"),
	Apollo.GetString("CRB_Guild_Member")
}

local kstrAlreadyInGuild = Apollo.GetString("GuildRegistration_AlreadyInAGuild")

function GuildRegistration:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function GuildRegistration:Init()
    Apollo.RegisterAddon(self)
end

function GuildRegistration:OnLoad() -- TODO: Only load when needed
	self.xmlDoc = XmlDoc.CreateFromFile("GuildRegistration.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function GuildRegistration:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("WindowManagementReady", 	"OnWindowManagementReady", self)

	Apollo.RegisterEventHandler("GuildResultInterceptResponse", "OnGuildResultInterceptResponse", self)

	self.timerErrorMessage = ApolloTimer.Create(3.00, false, "OnErrorMessageTimer", self)
	self.timerErrorMessage:Stop()

	self.timerSuccessMessage = ApolloTimer.Create(3.00, false, "OnSuccessfulMessageTimer", self)
	self.timerSuccessMessage:Stop()

	self.timerForcedRename = ApolloTimer.Create(5.50, false, "OnGuildRegistration_CheckForcedRename", self)
	self.timerForcedRename:Start() -- Check for Forced Renames

	Apollo.RegisterEventHandler("GuildRegistrarOpen", 		"OnGuildRegistrationOn", self)
	Apollo.RegisterEventHandler("GuildRegistrarClose",		"OnCancel", self)

    -- load our forms
    self.wndMain 			= Apollo.LoadForm(self.xmlDoc, "GuildRegistrationForm", nil, self)
	if self.locSavedWindowLocation then
		self.wndMain:MoveToLocation(self.locSavedWindowLocation)
	end
	self.wndGuildName 		= self.wndMain:FindChild("GuildNameString")
	self.wndRegisterBtn 	= self.wndMain:FindChild("RegisterBtn")
	self.wndAlert 			= self.wndMain:FindChild("AlertMessage")
	self.wndHolomarkCostume = self.wndMain:FindChild("HolomarkCostume")

	self.tCreate =
	{
		strName 		= "",
		eGuildType 		= GuildLib.GuildType_Guild,
		strMaster 		= kstrDefaultMaster,
		strCouncil 		= kstrDefaultCouncil,
		strMember 		= kstrDefaultMember,
		tHolomark		= {},
	}

	self.arGuildOptions = {} -- the various guild settings
	for idx = 1, 3 do
		self.arGuildOptions[idx] =
		{
			wndOption = self.wndMain:FindChild("OptionString_" .. idx),
			wndButton = self.wndMain:FindChild("LabelRevertBtn_" .. idx)
		}
		self.arGuildOptions[idx].wndOption:SetData(idx)
		self.arGuildOptions[idx].wndButton:SetData(idx)
	end

	self.wndMain:Show(false)

	self.wndSelectedBackground = nil
	self.wndSelectedForeground = nil

	self.wndMain:FindChild("CreditCost"):SetMoneySystem(Money.CodeEnumCurrencyType.Credits)

	self:InitializeHolomarkParts()
	self:ResetOptions()
end

function GuildRegistration:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("GuildRegistration_RegisterGuild")})
end

function GuildRegistration:OnGuildRegistrationOn()
	-- Check to see if the player has a guild. If so, route to the designer interface.
	local guildNew = nil

	for key, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr:GetType() == GuildLib.GuildType_Guild then
			guildNew = guildCurr
		end
	end

	self.wndMain:FindChild("GuildPermissionsAlert"):SetText("")
	self.wndMain:FindChild("CreditCost"):SetAmount(GuildLib.GetCreateCost(GuildLib.GuildType_Guild))

	if guildNew ~= nil then -- todo: permissions
		local tMyRankData = guildNew:GetRanks()[guildNew:GetMyRank()]

		if tMyRankData and tMyRankData.bEmblemAndStandard then
			Event_FireGenericEvent("Event_GuildDesignerOn")
			return
		else
			self.wndMain:FindChild("GuildPermissionsAlert"):SetText(kstrAlreadyInGuild)
		end
	end

	self:ResetOptions()

	self.wndMain:Show(true) -- show the window
	self.wndMain:ToFront()
end

function GuildRegistration:ResetOptions()
	for idx = 1, 3 do
		self.arGuildOptions[idx].wndOption:SetText(kstrDefaultOption[idx])
	end

	self.tCreate.strName = ""
	self.tCreate.strMaster = kstrDefaultMaster
	self.tCreate.strCouncil = kstrDefaultCouncil
	self.tCreate.strMember = kstrDefaultMember

	self.wndAlert:Show(false)
	self.wndAlert:FindChild("MessageAlertText"):SetText("")
	self.wndAlert:FindChild("MessageBodyText"):SetText("")
	self.wndGuildName:SetText("")
	self:SetDefaultHolomark()
	self:HelperClearFocus()
	self:UpdateOptions()
end

function GuildRegistration:OnNameChanging(wndHandler, wndControl)
	self.tCreate.strName = self.wndGuildName:GetText()
	self:UpdateOptions()
end

function GuildRegistration:OnOptionChanging(wndHandler, wndControl)
	local nRank = wndControl:GetData()

	if nRank == 1 then
		self.tCreate.strMaster = wndControl:GetText()
	elseif nRank == 2 then
		self.tCreate.strCouncil = wndControl:GetText()
	else
		self.tCreate.strMember = wndControl:GetText()
	end

	self:UpdateOptions()
end

function GuildRegistration:UpdateOptions()
	--see which fields need undo buttons
	local guildUpdated = nil
	local bNotInGuild = true

	for key, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr:GetType() == GuildLib.GuildType_Guild then
			guildUpdated = guildCurr
		end
	end

	if guildUpdated ~= nil then -- in a guild
		self.wndMain:FindChild("GuildPermissionsAlert"):SetText(kstrAlreadyInGuild)
		bNotInGuild = false
	else
		self.wndMain:FindChild("GuildPermissionsAlert"):SetText("")
	end

	for idx = 1, 3 do
		if self.arGuildOptions[idx].wndOption:GetText() ~= kstrDefaultOption[idx] then
			self.arGuildOptions[idx].wndButton:Enable(true)
		else
			self.arGuildOptions[idx].wndButton:Enable(false)
		end
	end

	self.wndMain:FindChild("CreditCost"):SetAmount(GuildLib.GetCreateCost(GuildLib.GuildType_Guild))

	--see if the Guild can be submitted
	local bHasName = self:HelperCheckForEmptyString(self.wndGuildName:GetText())
	local bHasMaster = self:HelperCheckForEmptyString(self.arGuildOptions[1].wndOption:GetText())
	local bHasCouncil = self:HelperCheckForEmptyString(self.arGuildOptions[2].wndOption:GetText())
	local bHasMember = self:HelperCheckForEmptyString(self.arGuildOptions[3].wndOption:GetText())
	local bHasValidLevel = (GameLib.GetPlayerLevel() or 1) >= GuildLib.GetMinimumLevel(self.tCreate.eGuildType)

	local bNameValid = GameLib.IsTextValid(self.wndGuildName:GetText(), GameLib.CodeEnumUserText.GuildName, eProfanityFilter)
	local bMasterValid = GameLib.IsTextValid(self.arGuildOptions[1].wndOption:GetText(), GameLib.CodeEnumUserText.GuildRankName, eProfanityFilter)
	local bCouncilValid = GameLib.IsTextValid(self.arGuildOptions[2].wndOption:GetText(), GameLib.CodeEnumUserText.GuildRankName, eProfanityFilter)
	local bMemberValid = GameLib.IsTextValid(self.arGuildOptions[3].wndOption:GetText(), GameLib.CodeEnumUserText.GuildRankName, eProfanityFilter)
	self.wndMain:FindChild("NameValidAlert"):Show(bHasName and not bNameValid)
	self.wndMain:FindChild("MasterRankValidAlert"):Show(bHasMaster and not bMasterValid)
	self.wndMain:FindChild("CouncilRankValidAlert"):Show(bHasCouncil and not bCouncilValid)
	self.wndMain:FindChild("MemberRankValidAlert"):Show(bHasMember and not bMemberValid)

	self.wndRegisterBtn:Enable(bNameValid and bMasterValid and bCouncilValid and bMemberValid and bHasName and bHasMaster and bHasCouncil and bHasMember and bNotInGuild and bHasValidLevel)

	if not bHasValidLevel then
		self.wndMain:FindChild("GuildPermissionsAlert"):SetText(Apollo.GetString("GuildRegistration_MustBeLvl12"))
	end
end

function GuildRegistration:HelperCheckForEmptyString(strText) -- make sure there's a valid string
	local strFirstChar
	local bHasText = false

	strFirstChar = string.find(strText, "%S")

	bHasText = strFirstChar ~= nil and string.len(strFirstChar) > 0
	return bHasText
end

function GuildRegistration:HelperClearFocus(wndHandler, wndControl)
	for idx = 1, 3 do
		self.arGuildOptions[idx].wndOption:ClearFocus()
	end

	self.wndGuildName:ClearFocus()
end

-- Guild Holomark Functions Below
function GuildRegistration:SetDefaultHolomark()

	self.tCreate.tHolomark =
	{
		tBackgroundIcon =
		{
			idPart = 4,
			idColor1 = 0,
			idColor2 = 0,
			idColor3 = 0,
		},

		tForegroundIcon =
		{
			idPart = 5,
			idColor1 = 0,
			idColor2 = 0,
			idColor3 = 0,
		},

		tScanLines =
		{
			idPart = 6,
			idColor1 = 0,
			idColor2 = 0,
			idColor3 = 0,
		},
	}

	local tHolomarkPartNames = { "tBackgroundIcon", "tForegroundIcon", "tScanLines" }

	local wndHolomarkBackgroundBtn = self.wndMain:FindChild("HolomarkContent:HolomarkBackgroundOption")
	local wndHolomarkForegroundBtn = self.wndMain:FindChild("HolomarkContent:HolomarkForegroundOption")
	local wndHolomarkBackgroundList = wndHolomarkBackgroundBtn:FindChild("HolomarkBackgroundPartWindow:HolomarkPartList")
	local wndHolomarkForegroundList = wndHolomarkForegroundBtn:FindChild("HolomarkForegroundPartWindow:HolomarkPartList")

	wndHolomarkBackgroundBtn:SetText(self.tHolomarkParts.tBackgroundIcons[1].strName)
	wndHolomarkForegroundBtn:SetText(self.tHolomarkParts.tForegroundIcons[1].strName)

	self:FakeRadio(wndHolomarkBackgroundList:GetChildren()[1]:FindChild("HolomarkPartBtn"), self.wndSelectedBackground)
	self:FakeRadio(wndHolomarkForegroundList:GetChildren()[1]:FindChild("HolomarkPartBtn"), self.wndSelectedForeground)

	wndHolomarkBackgroundList:SetVScrollPos(0)
	wndHolomarkForegroundList:SetVScrollPos(0)

	self.wndHolomarkCostume:SetCostumeToGuildStandard(self.tCreate.tHolomark)
end

-----------------------------------------------------------------------------------------------
-- GuildRegistrationForm Functions
-----------------------------------------------------------------------------------------------
function GuildRegistration:FakeRadio(wndNewOption, wndSavedOption)
	if wndSavedOption then
		wndSavedOption:SetCheck(false)
	end

	wndSavedOption = wndNewOption
	wndSavedOption:SetCheck(true)
end

function GuildRegistration:UseDefaultTitleBtn(wndHandler, wndControl) -- reset an option to its default
	local nRank = wndControl:GetData()
	self.arGuildOptions[nRank].wndOption:SetText(kstrDefaultOption[nRank])
	self:HelperClearFocus()
	self:UpdateOptions()
end

-- when the OK button is clicked
function GuildRegistration:OnRegisterBtn(wndHandler, wndControl)
	local tGuildInfo = self.tCreate

	local arGuldResultsExpected = { GuildLib.GuildResult_Success,  GuildLib.GuildResult_AtMaxGuildCount, GuildLib.GuildResult_InvalidGuildName,
									 GuildLib.GuildResult_GuildNameUnavailable, GuildLib.GuildResult_NotEnoughRenown, GuildLib.GuildResult_NotEnoughCredits,
									 GuildLib.GuildResult_InsufficientInfluence, GuildLib.GuildResult_NotHighEnoughLevel, GuildLib.GuildResult_YouJoined,
									 GuildLib.GuildResult_YouCreated, GuildLib.GuildResult_MaxArenaTeamCount, GuildLib.GuildResult_MaxWarPartyCount,
									 GuildLib.GuildResult_AtMaxCircleCount, GuildLib.GuildResult_VendorOutOfRange }

	Event_FireGenericEvent("GuildResultInterceptRequest", tGuildInfo.eGuildType, self.wndMain, arGuldResultsExpected )

	GuildLib.Create(tGuildInfo.strName, tGuildInfo.eGuildType, tGuildInfo.strMaster, tGuildInfo.strCouncil, tGuildInfo.strMember, tGuildInfo.tHolomark)
	self:HelperClearFocus()
	self.wndRegisterBtn:Enable(false)
	--NOTE: Requires a server response to progress
end

-- when the Cancel button is clicked
function GuildRegistration:OnCancel(wndHandler, wndControl)
	self.wndMain:Show(false) -- hide the window
	self:HelperClearFocus()
	self:ResetOptions()
	Event_CancelGuildRegistration()
end

function GuildRegistration:OnGuildResultInterceptResponse( guildCurr, eGuildType, eResult, wndRegistration, strAlertMessage )
	if eGuildType ~= GuildLib.GuildType_Guild or wndRegistration ~= self.wndMain then
		return
	end


	if not self.wndAlert or not self.wndAlert:IsValid() then
		return
	end

	if eResult == GuildLib.GuildResult_Success or eResult == GuildLib.GuildResult_YouCreated or eResult == GuildLib.GuildResult_YouJoined then
		self.wndAlert:FindChild("MessageAlertText"):SetText(Apollo.GetString("GuildRegistration_Success"))
		self.wndAlert:FindChild("MessageAlertText"):SetTextColor(ApolloColor.new("UI_TextHoloTitle"))

		self.timerSuccessMessage:Start()
	else
		self.wndAlert:FindChild("MessageAlertText"):SetText(Apollo.GetString("GuildRegistration_Whoops"))
		self.wndAlert:FindChild("MessageAlertText"):SetTextColor(ApolloColor.new("xkcdLightOrange"))

		self.timerErrorMessage:Start()
	end
	self.wndAlert:FindChild("MessageBodyText"):SetText(strAlertMessage)
	self.wndAlert:Show(true)
end

function GuildRegistration:OnSuccessfulMessageTimer()
	self:OnCancel()
end


function GuildRegistration:OnErrorMessageTimer()
	self.wndAlert:Show(false)
	self.wndRegisterBtn:Enable(true) -- safe to assume since it was clicked once
end

function GuildRegistration:OnPlayerCurrencyChanged()
end

-----------------------------------------------------------------------------------------------
-- Holomark Functions
-----------------------------------------------------------------------------------------------
function GuildRegistration:InitializeHolomarkParts()

	self.tHolomarkPartListItems = {}
	self.wndHolomarkOption = nil
	self.wndHolomarkOptionWindow = nil

	self.tHolomarkParts =
	{
		tBackgroundIcons = GuildLib.GetBannerBackgroundIcons(),
		tForegroundIcons = GuildLib.GetBannerForegroundIcons()
	}

	self.wndMain:FindChild("HolomarkBackgroundOption"):SetText(self.tHolomarkParts.tBackgroundIcons[1].strName)
	self.wndMain:FindChild("HolomarkForegroundOption"):SetText(self.tHolomarkParts.tForegroundIcons[1].strName)

	self:FillHolomarkPartList("Background")
	self:FillHolomarkPartList("Foreground")
end

function GuildRegistration:OnHolomarkPartCheck1( wndHandler, wndControl, eMouseButton )
	self.wndHolomarkOption = self.wndMain:FindChild("HolomarkBackgroundOption")
	self.wndHolomarkOptionWindow = self.wndMain:FindChild("HolomarkBackgroundPartWindow")
	self.wndHolomarkOptionWindow:SetData(1)
	self.wndHolomarkOptionWindow:Show(true)
end

function GuildRegistration:OnHolomarkPartUncheck1( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("HolomarkBackgroundPartWindow"):Show(false)
end

function GuildRegistration:OnHolomarkPartCheck2( wndHandler, wndControl, eMouseButton )
	self.wndHolomarkOption = self.wndMain:FindChild("HolomarkForegroundOption")
	self.wndHolomarkOptionWindow = self.wndMain:FindChild("HolomarkForegroundPartWindow")
	self.wndHolomarkOptionWindow:SetData(2)
	self.wndHolomarkOptionWindow:Show(true)
end

function GuildRegistration:OnHolomarkPartUncheck2( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("HolomarkForegroundPartWindow"):Show(false)
end

function GuildRegistration:FillHolomarkPartList( strPartType )
	local wndList = nil
	local tPartList = nil

	if strPartType == "Background" then
		wndList = self.wndMain:FindChild("HolomarkContent:HolomarkBackgroundOption:HolomarkBackgroundPartWindow:HolomarkPartList")
		tPartList = self.tHolomarkParts.tBackgroundIcons
	elseif strPartType == "Foreground" then
		wndList = self.wndMain:FindChild("HolomarkContent:HolomarkForegroundOption:HolomarkForegroundPartWindow:HolomarkPartList")
		tPartList = self.tHolomarkParts.tForegroundIcons
	end

	wndList:DestroyChildren()

	if tPartList == nil then
		return
	end

	for idx = 1, #tPartList do
		self:AddHolomarkPartItem(wndList, idx, tPartList[idx])
	end

	local wndDefault = wndList:GetChildren()[1]:FindChild("HolomarkPartBtn")
	if strPartType == "Background" and not self.wndSelectedBackground then
		self:FakeRadio(wndDefault, self.wndSelectedBackground)
	elseif strPartType == "Foreground" and not self.wndSelectedForeground then
		self:FakeRadio(wndDefault, self.wndSelectedForeground)
	end
end

function GuildRegistration:AddHolomarkPartItem(wndList, index, tPart)
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

function GuildRegistration:OnHolomarkPartSelectionClosed( wndHandler, wndControl )
	-- destroy all the wnd inside the list

	self.wndHolomarkOptionWindow:Show(false)
	self.wndHolomarkOptionWindow:GetParent():SetCheck(false)

	-- clear the list item array
	self.tHolomarkPartListItems = {}
	self.wndHolomarkOption = nil
	self.wndHolomarkOptionWindow = nil
end

function GuildRegistration:OnHolomarkPartItemSelected(wndHandler, wndControl)
	if not wndControl then
        return
    end

	local tPart = wndControl:GetData()
    if tPart ~= nil and self.wndHolomarkOption ~= nil then
		self.wndHolomarkOption:SetText(tPart.strName)

		local eType = self.wndHolomarkOptionWindow:GetData()
		if eType == 1 then
			self.tCreate.tHolomark.tBackgroundIcon.idPart = tPart.idBannerPart
			self:FakeRadio(wndHandler, self.wndSelectedBackground)
		elseif eType == 2 then
			self.tCreate.tHolomark.tForegroundIcon.idPart = tPart.idBannerPart
			self:FakeRadio(wndHandler, self.wndSelectedForeground)
		end

		self.wndHolomarkCostume:SetCostumeToGuildStandard(self.tCreate.tHolomark)
	end

	self:UpdateOptions()

	self:OnHolomarkPartSelectionClosed(wndHandler, wndControl)
end

-----------------------------------------------------------------------------------------------
-- Forced Rename Code
-----------------------------------------------------------------------------------------------
function GuildRegistration:OnGuildRegistration_CheckForcedRename()
	for idx, guildCurr in pairs(GuildLib.GetGuilds()) do
		if guildCurr and guildCurr:GetFlags() and guildCurr:GetFlags().bRename and guildCurr:GetMyRank() == 1 then
			local strGuildType = ktstrGuildTypes[guildCurr:GetType()]
			self.wndForcedRename = Apollo.LoadForm(self.xmlDoc, "RenameSocialAlert", nil, self)
			self.wndForcedRename:FindChild("TitleBlock"):SetText(String_GetWeaselString(Apollo.GetString("ForceRenameSocial_TitleBlock"), strGuildType, guildCurr:GetName()))
			self.wndForcedRename:FindChild("RenameEditBox"):SetMaxTextLength(GameLib.GetTextTypeMaxLength(GameLib.CodeEnumUserText.GuildName))
			self.wndForcedRename:FindChild("StatusValidAlert"):Show(true)
			self.wndForcedRename:FindChild("RenameSocialConfirm"):SetData(guildCurr)
			self.wndForcedRename:FindChild("RenameSocialConfirm"):Enable(false)
			self.wndForcedRename:Invoke()

			-- Resize
			local strRenameBodyText = String_GetWeaselString(Apollo.GetString("ForceRenameSocial_BodyBlock"), strGuildType)
			local nLeft, nTop, nRight, nBottom = self.wndForcedRename:GetAnchorOffsets()
			self.wndForcedRename:FindChild("BodyBlock"):SetAML(string.format("<T Font=\"CRB_InterfaceMedium\" TextColor=\"UI_TextHoloBody\">%s</T>", strRenameBodyText))
			self.wndForcedRename:FindChild("BodyBlock"):SetHeightToContentHeight()
			self.wndForcedRename:SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.wndForcedRename:FindChild("BodyBlock"):GetHeight() + 310)

			-- Hack for descenders
			nLeft, nTop, nRight, nBottom = self.wndForcedRename:FindChild("BodyBlock"):GetAnchorOffsets()
			self.wndForcedRename:FindChild("BodyBlock"):SetAnchorOffsets(nLeft, nTop, nRight, nTop + self.wndForcedRename:FindChild("BodyBlock"):GetHeight() + 5)

			return -- Do them one at a time
		end
	end
end

function GuildRegistration:OnRenameSocialCancel()
	if self.wndForcedRename and self.wndForcedRename:IsValid() then
		self.wndForcedRename:Destroy()
		self.wndForcedRename = nil
	end
end

function GuildRegistration:OnRenameEditBoxChanged(wndHandler, wndControl)
	local strInput = wndHandler:GetText()
	local bValid = strInput and GameLib.IsTextValid(strInput, GameLib.CodeEnumUserText.GuildName, eProfanityFilter)
	self.wndForcedRename:FindChild("RenameSocialConfirm"):Enable(bValid)
	self.wndForcedRename:FindChild("StatusValidAlert"):Show(not bValid)
end

function GuildRegistration:OnRenameSocialConfirm(wndHandler, wndControl)
	wndHandler:GetData():Rename(self.wndForcedRename:FindChild("RenameEditBox"):GetText())
	self:OnRenameSocialCancel()
	self.timerForcedRename:Start()
end

local GuildRegistrationInst = GuildRegistration:new()
GuildRegistrationInst:Init()
