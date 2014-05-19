-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildInfo
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Apollo"
require "ChatSystemLib"
require "GuildLib"
require "GuildTypeLib"
require "ChatChannelLib"

local GuildInfo = {}

function GuildInfo:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function GuildInfo:Init()
    Apollo.RegisterAddon(self)
end

function GuildInfo:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GuildInfo.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function GuildInfo:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
    Apollo.RegisterEventHandler("Guild_ToggleInfo",         "OnToggleInfo", self)
    Apollo.RegisterEventHandler("GuildWindowHasBeenClosed",	"OnClose", self)
	
	Apollo.RegisterEventHandler("GuildNameplateChange", 	"OnGuildNameplateChange", 	self) -- notification that your guild nameplate has changed
	Apollo.RegisterEventHandler("GuildRoster", 				"OnGuildRoster", 			self) -- notification that a guild roster was recieved.
	Apollo.RegisterEventHandler("GuildLoaded", 				"OnGuildLoaded", 			self) -- notification that your guild or a society has loaded.
	Apollo.RegisterEventHandler("GuildFlags", 				"OnGuildFlags", 			self) -- notification that your guild's flags have changed.
	Apollo.RegisterEventHandler("GuildName", 				"OnGuildName", 				self) -- notification that the guild name has changed.
	Apollo.RegisterEventHandler("GuildMessageOfTheDay", 	"OnGuildMessageUpdated", 	self) -- notification that the guild MotD has changed
	Apollo.RegisterEventHandler("GuildInfoMessage", 		"OnGuildMessageUpdated", 	self) -- notification that the guild info has changed
	Apollo.RegisterEventHandler("GuildEventLogChange", 		"OnGuildEventLogChanged", 	self) -- notification that the list of guild events has changed
end

function GuildInfo:Initialize(wndParent)
	local guildOwner = wndParent:GetParent():GetData()
	if not guildOwner then
		return
	end

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "GuildInfoForm", wndParent, self)
    self.wndMain:Show(true)

	self.tGuildLeader = nil
	
	self.wndMain:SetData(guildOwner)
end

function GuildInfo:OnToggleInfo(wndParent)
	local guildOwner = wndParent:GetParent():GetData()
	if not guildOwner then
		return
	end
	
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize(wndParent)
	else
		self.wndMain:Show(true)
	end
	
	guildOwner:RequestMembers()
	guildOwner:RequestEventLogList()
end

function GuildInfo:OnRosterTimer()
	if self.tGuildLeader then
		self:PopulateInfoPane()
	end
end

function GuildInfo:OnClose()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
	end
end

function GuildInfo:OnGuildRoster(guildOwner, tRoster)
	if self.wndMain and self.wndMain:IsValid() and guildOwner == self.wndMain:GetData() then
		for key, tCurrMember in pairs(tRoster or {}) do
			if tCurrMember.nRank == 1 then
				self.tGuildLeader = tCurrMember
				break
			end
		end
		self:OnRosterTimer()
	end
end

-----------------------------------------------------------------------------------------------
-- Info Panel Functions
-----------------------------------------------------------------------------------------------

function GuildInfo:PopulateInfoPane()
	local guildOwner = self.wndMain:GetData()
	if not guildOwner then
		return
	end

	local eMyRank = guildOwner:GetMyRank()
	local tMyRankPermissions = guildOwner:GetRanks()[eMyRank]
	-- Guild Tax
	local tGuildFlags = guildOwner:GetFlags()
	self.wndMain:FindChild("GuildTaxOnBtn"):SetCheck(tGuildFlags.bTax)
	self.wndMain:FindChild("GuildTaxOffBtn"):SetCheck(not tGuildFlags.bTax)
	self.wndMain:FindChild("GuildMemberGuildTaxLabel"):SetText(String_GetWeaselString(Apollo.GetString("Guild_GuildTaxLabel"), tGuildFlags.bTax and Apollo.GetString("MatchMaker_FlagOn") or Apollo.GetString("MatchMaker_FlagOff")))
	self.wndMain:FindChild("GuildMemberGuildTaxText"):SetText(tGuildFlags.bTax and Apollo.GetString("Guild_TaxActive") or Apollo.GetString("Options_AddonOff"))
	self.wndMain:FindChild("GuildTaxBtnContainer"):Show(tMyRankPermissions.bChangeRankPermissions) -- GOTCHA: This is actually guild tax, it uses an existing

	-- More data
	self.wndMain:FindChild("EditMessageBtn"):Show(tMyRankPermissions.bMessageOfTheDay)
	self.wndMain:FindChild("EditInfoBtn"):Show(tMyRankPermissions.bMessageOfTheDay)
	self.wndMain:FindChild("GuildMasterName"):SetText(self.tGuildLeader and self.tGuildLeader.strName or "")
	self.wndMain:FindChild("GuildCreatedDate"):SetText(self:HelperRelativeTimeToString(guildOwner:GetCreationDate()))
	self.wndMain:FindChild("GuildMemberCount"):SetText(String_GetWeaselString(Apollo.GetString("Guild_MemberCount"), guildOwner:GetMemberCount(), guildOwner:GetOnlineMemberCount()))
	self.wndMain:FindChild("GuildMotD"):SetText(guildOwner:GetMessageOfTheDay())
	self.wndMain:FindChild("GuildInfoText"):SetText(guildOwner:GetInfoMessage())
	self.wndMain:FindChild("GuildName"):SetText(guildOwner:GetName())
	self.wndMain:FindChild("HolomarkCostume"):SetCostumeToGuildStandard(guildOwner:GetStandard())
	self.wndMain:FindChild("NewsPaneList"):DestroyChildren()

	guildOwner:RequestEventLogList()
end

function GuildInfo:AddNewsListItem(tEventLog, index)
	local guildOwner = self.wndMain:GetData()
	if not guildOwner or not tEventLog then
		return
	end

	-- TODO: Need to get the GuildEventType values to Lua
	local strMessage = ""
	if tEventLog.eType == GuildLib.CodeEnumGuildEventType.Achievement and tEventLog.achEarned ~= nil then
		strMessage = String_GetWeaselString(Apollo.GetString("Guild_AchievementEarned"), guildOwner:GetName(), tEventLog.achEarned:GetName())
	elseif tEventLog.eType == GuildLib.CodeEnumGuildEventType.PerkUnlock and tEventLog.tGuildPerk ~= nil then
		strMessage = String_GetWeaselString(Apollo.GetString("Guild_UnlockedPerk"), guildOwner:GetName(), tEventLog.tGuildPerk.strTitle)
	elseif tEventLog.eType == GuildLib.CodeEnumGuildEventType.PerkActivate and tEventLog.tGuildPerk ~= nil then
		strMessage = String_GetWeaselString(Apollo.GetString("Guild_AchievementEarned"), guildOwner:GetName(), tEventLog.tGuildPerk.strTitle)
	elseif tEventLog.eType == GuildLib.CodeEnumGuildEventType.MemberAdded then
		strMessage = String_GetWeaselString(Apollo.GetString("Guild_MemberJoined"), tEventLog.strMemberName)
	elseif tEventLog.eType == GuildLib.CodeEnumGuildEventType.MemberRemoved then
		strMessage = String_GetWeaselString(Apollo.GetString("Guild_MemberLeft"), tEventLog.strMemberName)
	elseif tEventLog.eType == GuildLib.CodeEnumGuildEventType.MemberRankChanged then
		local strChange = Apollo.GetString("Guild_Promoted")
		if tEventLog.nOldRank < tEventLog.nNewRank then
			strChange = Apollo.GetString("Guild_Demoted")
		end
		strMessage = String_GetWeaselString(Apollo.GetString("Guild_RankChange"), tEventLog.strMemberName, strChange, guildOwner:GetRanks()[tEventLog.nNewRank + 1].strName)
	elseif tEventLog.eType == GuildLib.CodeEnumGuildEventType.MessageOfTheDay then
		strMessage = Apollo.GetString("Guild_MOTDUpdated")
	else
		-- Error: Unhandled EventLog type
		guildOwner:GetChannel():Post(String_GetWeaselString(Apollo.GetString("Guild_UnknownLogType"), tEventLog.eType, "" ))
		return
	end

	-- NOTE: The time is also stored as a relative float in the parameter "fCreationTime"
	local strTimestamp = String_GetWeaselString(Apollo.GetString("Guild_NewsListItem"), self:HelperRelativeTimeToString(tEventLog.fCreationTime), strMessage)
	local wndListItem = Apollo.LoadForm(self.xmlDoc, "GuildNewsListItem", self.wndMain:FindChild("NewsPaneList"), self)
	wndListItem:FindChild("GuildNewsItemText"):SetText(strTimestamp)
end

-----------------------------------------------------------------------------------------------
-- Buttons
-----------------------------------------------------------------------------------------------

function GuildInfo:OnGuildTaxToggle(wndHandler, wndControl)
	local guildOwner = self.wndMain:GetData()
	if not guildOwner then
		return
	end

	local bOn = wndHandler:GetName() == "GuildTaxOnBtn" -- TODO HACK
	local tLocalTable =
	{
		bTax = bOn
	}
	guildOwner:SetFlags(tLocalTable)
	self.wndMain:FindChild("GuildMemberGuildTaxLabel"):SetText(String_GetWeaselString(Apollo.GetString("Guild_GuildTaxLabel"), bOn and Apollo.GetString("MatchMaker_FlagOn") or Apollo.GetString("MatchMaker_FlagOff")))
end

function GuildInfo:OnMotDEditClick(wndHandler, wndControl)
	local guildOwner = self.wndMain:GetData()
	if not guildOwner then
		return
	end

	self.wndMain:FindChild("EditMotDContainer"):Show(wndHandler:IsChecked())
	if wndHandler:IsChecked() then
		self.wndMain:FindChild("EditMotDEditBox"):SetText(guildOwner:GetMessageOfTheDay())
		self.wndMain:FindChild("EditMotDEditBox"):SetFocus()
	end

	self:HelperValidateMotdEdit()
end

function GuildInfo:OnEditMotDCloseBtn() -- The Window Close Event can also route here
	self.wndMain:FindChild("EditMotDEditBox"):SetText("")
	self.wndMain:FindChild("EditMotDContainer"):Show(false)
	self.wndMain:FindChild("EditMessageBtn"):SetCheck(false)
end

function GuildInfo:OnEditMotDEditBoxReturn(wndHandler, wndControl, strText)
	if wndHandler and wndHandler:GetData() and string.len(strText) > 0 then
		local guildOwner = self.wndMain:GetData()
		if guildOwner then
			guildOwner:SetMessageOfTheDay(strText)
		end
	end
	self:OnEditMotDCloseBtn()
end

function GuildInfo:OnEditMotDConfirmBtn(wndHandler, wndControl)
	if wndHandler and wndHandler:GetParent():FindChild("EditMotDEditBox") then
		local wndEditBox = wndHandler:GetParent():FindChild("EditMotDEditBox")

		if wndEditBox then
			local guildOwner = self.wndMain:GetData()
			if guildOwner then
				guildOwner:SetMessageOfTheDay(wndEditBox:GetText())
			end
		end
	end
	self:OnEditMotDCloseBtn()
end

function GuildInfo:OnEditMotDEditBoxChanged(wndHandler, wndControl)
	self:HelperValidateMotdEdit()
end

function GuildInfo:HelperValidateMotdEdit()

	local wndEditBox = self.wndMain:FindChild("EditMotDEditBox")
	if wndEditBox == nil then return end

	local wndEditMotDConfirmBtn = self.wndMain:FindChild("EditMotDConfirmBtn")
	if wndEditMotDConfirmBtn == nil then return end

	local strMotd = wndEditBox:GetText()

	wndEditMotDConfirmBtn:Enable(GameLib.IsTextValid(strMotd, GameLib.CodeEnumUserText.GuildMessageOfTheDay, GameLib.CodeEnumUserTextFilterClass.Strict))
end

function GuildInfo:OnInfoEditClick(wndHandler, wndControl)
	local guildOwner = self.wndMain:GetData()
	if not guildOwner then
		return
	end

	self.wndMain:FindChild("EditInfoContainer"):Show(wndHandler:IsChecked())
	if wndHandler:IsChecked() then
		self.wndMain:FindChild("EditInfoEditBox"):SetText(guildOwner:GetInfoMessage())
		self.wndMain:FindChild("EditInfoEditBox"):SetFocus()
	end

	self:HelperValidateInfoEdit()
end

function GuildInfo:OnEditInfoCloseBtn() -- The Window Close Event can also route here
	self.wndMain:FindChild("EditInfoEditBox"):SetText("")
	self.wndMain:FindChild("EditInfoContainer"):Show(false)
	self.wndMain:FindChild("EditInfoBtn"):SetCheck(false)
end

function GuildInfo:OnEditInfoEditBoxReturn(wndHandler, wndControl, strText)
	if wndHandler and wndHandler:GetData() then
		local guildOwner = self.wndMain:GetData()
		if guildOwner then
			guildOwner:SetInfoMessage(strText)
		end
	end
	self:OnEditInfoCloseBtn()
end

function GuildInfo:OnEditInfoConfirmBtn(wndHandler, wndControl)
	if wndHandler and wndHandler:GetParent():FindChild("EditInfoEditBox") then
		local wndEditBox = wndHandler:GetParent():FindChild("EditInfoEditBox")

		if wndEditBox then
			local guildOwner = self.wndMain:GetData()
			if guildOwner then
				guildOwner:SetInfoMessage(wndEditBox:GetText())
			end
		end
	end
	self:OnEditInfoCloseBtn()
end

function GuildInfo:OnEditInfoEditBoxChanged(wndHandler, wndControl)
	self:HelperValidateInfoEdit()
end

function GuildInfo:HelperValidateInfoEdit()
	local wndEditBox = self.wndMain:FindChild("EditInfoEditBox")
	if not wndEditBox then return end

	local wndEditInfoConfirmBtn = self.wndMain:FindChild("EditInfoConfirmBtn")
	if not wndEditInfoConfirmBtn then return end

	local strInfo = wndEditBox:GetText()

	wndEditInfoConfirmBtn:Enable(GameLib.IsTextValid(strInfo, GameLib.CodeEnumUserText.GuildInfoMessage, GameLib.CodeEnumUserTextFilterClass.Strict))
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function GuildInfo:HelperRelativeTimeToString(fDays)
	if fDays == 0 or fDays == nil then
		return Apollo.GetString("Guild_Now")
	end

	fDays = math.abs(fDays)

	local tTimeData =
	{
		["name"]	= "",
		["count"]	= nil,
	}

	local nYears = math.floor(fDays / 365)
	local nMonths = math.floor(fDays / 30)
	local nWeeks = math.floor(fDays / 7)
	local fDaysRounded = math.floor(fDays / 1)
	local fHours = fDays * 24
	local nHoursRounded = math.floor(fHours)
	local nMinutes = math.floor(fHours * 60)

	if nYears > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Year")
		tTimeData["count"] = nYears
	elseif nMonths > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Month")
		tTimeData["count"] = nMonths
	elseif nWeeks > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Week")
		tTimeData["count"] = nWeeks
	elseif fDaysRounded > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Day")
		tTimeData["count"] = fDaysRounded
	elseif nHoursRounded > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Hour")
		tTimeData["count"] = nHoursRounded
	elseif nMinutes > 0 then
		tTimeData["name"] = Apollo.GetString("CRB_Min")
		tTimeData["count"] = nMinutes
	else
		tTimeData["name"] = Apollo.GetString("CRB_Min")
		tTimeData["count"] = 1
	end

	return String_GetWeaselString(Apollo.GetString("CRB_TimeOffline"), tTimeData)
end

-----------------------------------------------------------------------------------------------
-- Feedback Messages
-----------------------------------------------------------------------------------------------
function GuildInfo:OnGuildNameplateChange(guildShown)
	if self.wndMain and self.wndMain:IsValid() then
		if guildShown ~= nil and guildShown:GetChannel() ~= nil then
			guildShown:GetChannel():Post(Apollo.GetString("Guild_ChangedNameplate"), "" )
		end
	end
end

function GuildInfo:OnGuildMessageUpdated(guildOwner)
	if self.wndMain:GetData() == guildOwner and self.wndMain and self.wndMain:IsValid() then
		self:PopulateInfoPane()
	end
end

function GuildInfo:OnGuildEventLogChanged(guildUpdated)
	if not self.wndMain or not self.wndMain:IsValid() then
		return
	end
	
	if self.wndMain:GetData() ~= guildUpdated then
		return
	end

	self.wndMain:FindChild("NewsPaneList"):DestroyChildren()
	for idx, tEventLog in pairs(guildUpdated:GetEventLogs()) do
		self:AddNewsListItem(tEventLog, idx)
	end
	self.wndMain:FindChild("NewsPaneList"):ArrangeChildrenVert(0)
end

function GuildInfo:OnGuildResult(guildSender, strName, nRank, eResult)
	if eResult == GuildLib.GuildResult_PendingInviteExpired and self.wndGuildInvite ~= nil then
		self.wndGuildInvite:Destroy()
	end
end

function GuildInfo:OnGuildLoaded(guildLoaded)
	local tGuildFlags = guildLoaded:GetFlags()
	local channelGuild = guildLoaded:GetChannel()
	channelGuild:Post(String_GetWeaselString(Apollo.GetString("Guild_GuildWelcome"), guildLoaded:GetName()))
	channelGuild:Post(guildLoaded:GetMessageOfTheDay())

	if tGuildFlags.bTax then
		channelGuild:Post(Apollo.GetString("Guild_TaxActive"))
	end

	if self.wndMain and self.wndMain:IsShown() then
		self:OnToggleGuildWindow()
	end
end

function GuildInfo:OnGuildFlags(guildUpdated)
	guildUpdated:GetChannel():Post(Apollo.GetString("Guild_FlagsChanged"))
end

function GuildInfo:OnGuildName(guildUpdated)
	guildUpdated:GetChannel():Post(String_GetWeaselString(Apollo.GetString("Guild_NameChanged"), guildUpdated:GetName() ))
end

local GuildInst = GuildInfo:new()
GuildInst:Init()
