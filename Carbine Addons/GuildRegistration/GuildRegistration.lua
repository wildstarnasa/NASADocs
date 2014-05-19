-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildRegistration
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
-- GuildRegistration Module Definition
-----------------------------------------------------------------------------------------------
local GuildRegistration = {}

local kcrDefaultText = CColor.new(135/255, 135/255, 135/255, 1.0)
local kcrHighlightedText = CColor.new(0, 1.0, 1.0, 1.0)
local eProfanityFilter = GameLib.CodeEnumUserTextFilterClass.Strict
local knSavedVersion = 0

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

function GuildRegistration:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locWindowLocation = self.wndMain and self.wndMain:GetLocation() or self.locSavedWindowLocation
	
	local tSaved = 
	{
		tWindowLocation  = locWindowLocation:ToTable(),
		nSavedVersion = knSaveVersion
	}
	
	return tSaved
end

function GuildRegistration:OnRestore(eType, tSavedData)
	if tSavedData and tSavedData.nSavedVersion == knSaveVersion then
		if tSavedData.tWindowLocation then
			self.locSavedWindowLocation = WindowLocation.new(tSavedData.tWindowLocation)
		end
	end
end

function GuildRegistration:OnLoad() -- TODO: Only load when needed
	self.xmlDoc = XmlDoc.CreateFromFile("GuildRegistration.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function GuildRegistration:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("GuildResultInterceptResponse", "OnGuildResultInterceptResponse", self)
	Apollo.RegisterTimerHandler("SuccessfulMessageTimer", 	"OnSuccessfulMessageTimer", self)
	Apollo.RegisterTimerHandler("ErrorMessageTimer", 		"OnErrorMessageTimer", self)
	Apollo.RegisterEventHandler("GuildRegistrarOpen", 		"OnGuildRegistrationOn", self)
	Apollo.RegisterEventHandler("PlayerCurrencyChanged",	"OnPlayerCurrencyChanged", self)
    --Apollo.RegisterEventHandler("ToggleGuildRegistration",	"OnGuildRegistrationOn", self) -- TODO: War Parties NYI
    --Apollo.RegisterSlashCommand("guildreg", 					"OnGuildRegistrationOn", self)

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

	self.wndMain:FindChild("CreditCost"):SetMoneySystem(Money.CodeEnumCurrencyType.Credits)
	self.wndMain:FindChild("CreditCurrent"):SetMoneySystem(Money.CodeEnumCurrencyType.Credits)

	self:InitializeHolomarkParts()
	self:ResetOptions()
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
	self.wndMain:FindChild("CreditCurrent"):SetAmount(GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Credits):GetAmount(), true)

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
	self.wndMain:FindChild("CreditCurrent"):SetAmount(GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Credits):GetAmount(), true)

	--see if the Guild can be submitted
	local bHasName = self:HelperCheckForEmptyString(self.wndGuildName:GetText())
	local bHasMaster = self:HelperCheckForEmptyString(self.arGuildOptions[1].wndOption:GetText())
	local bHasCouncil = self:HelperCheckForEmptyString(self.arGuildOptions[2].wndOption:GetText())
	local bHasMember = self:HelperCheckForEmptyString(self.arGuildOptions[3].wndOption:GetText())

	local bNameValid = GameLib.IsTextValid(self.wndGuildName:GetText(), GameLib.CodeEnumUserText.GuildName, eProfanityFilter)
	local bMasterValid = GameLib.IsTextValid(self.arGuildOptions[1].wndOption:GetText(), GameLib.CodeEnumUserText.GuildRankName, eProfanityFilter)
	local bCouncilValid = GameLib.IsTextValid(self.arGuildOptions[2].wndOption:GetText(), GameLib.CodeEnumUserText.GuildRankName, eProfanityFilter)
	local bMemberValid = GameLib.IsTextValid(self.arGuildOptions[3].wndOption:GetText(), GameLib.CodeEnumUserText.GuildRankName, eProfanityFilter)
	self.wndMain:FindChild("NameValidAlert"):Show(bHasName and not bNameValid)
	self.wndMain:FindChild("MasterRankValidAlert"):Show(bHasMaster and not bMasterValid)
	self.wndMain:FindChild("CouncilRankValidAlert"):Show(bHasCouncil and not bCouncilValid)
	self.wndMain:FindChild("MemberRankValidAlert"):Show(bHasMember and not bMemberValid)

	self.wndRegisterBtn:Enable(bNameValid and bMasterValid and bCouncilValid and bMemberValid and bHasName and bHasMaster and bHasCouncil and bHasMember and bNotInGuild)
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

	for idx, tPartList in ipairs(self.tHolomarkParts) do
		for key, tPart in ipairs(tPartList) do
			if tPart.idBannerPart == self.tCreate.tHolomark[tHolomarkPartNames[idx]].idPart then
				self.wndMain:FindChild("HolomarkOption."..idx):SetText(tPart.strName)
			end
		end
	end

	self.wndHolomarkCostume:SetCostumeToGuildStandard(self.tCreate.tHolomark)
end

-----------------------------------------------------------------------------------------------
-- GuildRegistrationForm Functions
-----------------------------------------------------------------------------------------------
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
		Apollo.CreateTimer("SuccessfulMessageTimer", 3.00, false)
	else
		self.wndAlert:FindChild("MessageAlertText"):SetText(Apollo.GetString("GuildRegistration_Whoops"))
		Apollo.CreateTimer("ErrorMessageTimer", 3.00, false)
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
	self.wndMain:FindChild("CreditCurrent"):SetAmount(GameLib.GetPlayerCurrency(Money.CodeEnumCurrencyType.Credits):GetAmount(), true)
end

-----------------------------------------------------------------------------------------------
-- Holomark Functions
-----------------------------------------------------------------------------------------------
function GuildRegistration:InitializeHolomarkParts()

	self.tHolomarkPartListItems = {}
	self.wndHolomarkOption = nil
	self.wndHolomarkOptionList = nil

	self.tHolomarkParts = {}
	self.tHolomarkParts[1] = GuildLib.GetBannerBackgroundIcons()
	self.tHolomarkParts[2] = GuildLib.GetBannerForegroundIcons()
	self.tHolomarkParts[3] = GuildLib.GetBannerScanLines()

	for idx, tParts in ipairs(self.tHolomarkParts) do
		local tDefaultPart = tParts[1]
		if tDefaultPart ~= nil then
			self.wndMain:FindChild("HolomarkOption."..idx):SetText(tDefaultPart.strName)
		end
	end
end

function GuildRegistration:OnHolomarkPartCheck1( wndHandler, wndControl, eMouseButton )
	self:FillHolomarkPartList(1)
	self.wndHolomarkOption = self.wndMain:FindChild("HolomarkOption.1")
	self.wndHolomarkOptionList = self.wndMain:FindChild("HolomarkPartWindow.1")
	self.wndHolomarkOptionList:SetData(1)
	self.wndHolomarkOptionList:Show(true)
end

function GuildRegistration:OnHolomarkPartUncheck1( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("HolomarkPartWindow.1"):Show(false)
end

function GuildRegistration:OnHolomarkPartCheck2( wndHandler, wndControl, eMouseButton )
	self:FillHolomarkPartList(2)
	self.wndHolomarkOption = self.wndMain:FindChild("HolomarkOption.2")
	self.wndHolomarkOptionList = self.wndMain:FindChild("HolomarkPartWindow.2")
	self.wndHolomarkOptionList:SetData(2)
	self.wndHolomarkOptionList:Show(true)
end

function GuildRegistration:OnHolomarkPartUncheck2( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("HolomarkPartWindow.2"):Show(false)
end

function GuildRegistration:OnHolomarkPartCheck3( wndHandler, wndControl, eMouseButton )
	self:FillHolomarkPartList(3)
	self.wndHolomarkOption = self.wndMain:FindChild("HolomarkOption.3")
	self.wndHolomarkOptionList = self.wndMain:FindChild("HolomarkPartWindow.3")
	self.wndHolomarkOptionList:SetData(3)
	self.wndHolomarkOptionList:Show(true)
end

function GuildRegistration:OnHolomarkPartUncheck3( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("HolomarkPartWindow.3"):Show(false)
end

function GuildRegistration:FillHolomarkPartList( ePartType )
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
	for idx,wnd in ipairs(self.tHolomarkPartListItems) do
		wnd:Destroy()
	end

	self.wndHolomarkOptionList:Show(false)

	-- clear the list item array
	self.tHolomarkPartListItems = {}
	self.wndHolomarkOption = nil
	self.wndHolomarkOptionList = nil
end

function GuildRegistration:OnHolomarkPartItemSelected(wndHandler, wndControl)
	if not wndControl then
        return
    end

	local tPart = wndControl:GetData()
    if tPart ~= nil and self.wndHolomarkOption ~= nil then
		self.wndHolomarkOption:SetText(tPart.strName)

		local eType = self.wndHolomarkOptionList:GetData()
		if eType == 1 then
			self.tCreate.tHolomark.tBackgroundIcon.idPart = tPart.idBannerPart
		elseif eType == 2 then
			self.tCreate.tHolomark.tForegroundIcon.idPart = tPart.idBannerPart
		elseif eType == 3 then
			self.tCreate.tHolomark.tScanLines.idPart = tPart.idBannerPart
		end

		self.wndMain:FindChild("HolomarkOption." .. eType):SetCheck(false)

		self.wndHolomarkCostume:SetCostumeToGuildStandard(self.tCreate.tHolomark)
	end

	self:UpdateOptions()

	self:OnHolomarkPartSelectionClosed(wndHandler, wndControl)
end

-----------------------------------------------------------------------------------------------
-- GuildRegistration Instance
-----------------------------------------------------------------------------------------------
local GuildRegistrationInst = GuildRegistration:new()
GuildRegistrationInst:Init()
