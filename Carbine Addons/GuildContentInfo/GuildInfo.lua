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

	o.tWndRefs = {}

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

	self.tWndRefs.wndNewsGrid = self.wndMain:FindChild("NewsPane:NewsFraming:NewsPaneList:NewsGrid")
	self.tWndRefs.wndGuildMemberGuildTaxLabel = self.wndMain:FindChild("GuildMemberGuildTaxLabel")

	self.tGuildLeader = nil
	
	self.wndMain:SetData(guildOwner)
	
	self.wndMain:FindChild("EditInfoBtn"):AttachWindow(self.wndMain:FindChild("EditAdditionalInfo"))
	self.wndMain:FindChild("EditMessageBtn"):AttachWindow(self.wndMain:FindChild("EditMOTD"))
	self.wndMain:FindChild("NewsPane"):ArrangeChildrenVert(1)
end

function GuildInfo:OnToggleInfo(wndParent)
	local guildOwner = wndParent:GetParent():GetData()
	if not guildOwner then
		return
	end
	
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize(wndParent)
		guildOwner:RequestMembers()
		guildOwner:RequestEventLogList()
	else
		self.wndMain:Show(true)
	end
end

function GuildInfo:OnClose()
	if self.wndMain and self.wndMain:IsValid() then
		self.wndMain:Destroy()
		self.wndMain = nil
		self.tWndRefs = {}
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
		
		if self.tGuildLeader then
			self:PopulateInfoPane()
		end
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
	self.tWndRefs.wndGuildMemberGuildTaxLabel:SetText(String_GetWeaselString(Apollo.GetString("Guild_GuildTaxLabel"), tGuildFlags.bTax and Apollo.GetString("MatchMaker_FlagOn") or Apollo.GetString("MatchMaker_FlagOff")))
	self.wndMain:FindChild("GuildTaxBtnContainer"):Show(tMyRankPermissions.bChangeRankPermissions) -- GOTCHA: This is actually guild tax, it uses an existing
	-- More data
	self.wndMain:FindChild("EditMessageBtn"):Show(tMyRankPermissions.bMessageOfTheDay)
	self.wndMain:FindChild("EditInfoBtn"):Show(tMyRankPermissions.bMessageOfTheDay)
	self.wndMain:FindChild("GuildMasterName"):SetAML(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff5f6662\">%s %s</T><T Font=\"CRB_InterfaceSmall_BB\" TextColor=\"UI_TextMetalBodyHighlight\">%s</T>", Apollo.GetString("GuildInfo_LeaderName"), " ", self.tGuildLeader and self.tGuildLeader.strName or ""))
	self.wndMain:FindChild("GuildCreatedDate"):SetAML(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff5f6662\">%s %s</T><T Font=\"CRB_InterfaceSmall_BB\" TextColor=\"UI_TextMetalBodyHighlight\">%s</T>", Apollo.GetString("GuildInfo_DateCreated"), " ", self:HelperRelativeTimeToString(guildOwner:GetCreationDate())))
	self.wndMain:FindChild("GuildMemberCount"):SetAML(string.format("<T Font=\"CRB_InterfaceSmall\" TextColor=\"ff5f6662\">%s %s</T><T Font=\"CRB_InterfaceSmall_BB\" TextColor=\"UI_TextMetalBodyHighlight\">%s</T>", Apollo.GetString("GuildInfo_MemberCount"), " ", String_GetWeaselString(Apollo.GetString("Guild_MemberCount"), guildOwner:GetMemberCount(), guildOwner:GetOnlineMemberCount())))
	self.wndMain:FindChild("GuildMotD"):SetText(guildOwner:GetMessageOfTheDay())
	self.wndMain:FindChild("GuildInfoText"):SetText(guildOwner:GetInfoMessage())
	self.wndMain:FindChild("GuildName"):SetText(guildOwner:GetName())
	self.wndMain:FindChild("HolomarkCostume"):SetCostumeToGuildStandard(guildOwner:GetStandard())
end

function GuildInfo:GetNewsListItemText(tEventLog, index)
	local guildOwner = self.wndMain:GetData()
	if not guildOwner or not tEventLog then
		return
	end

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
		return nil
	end
	
	return String_GetWeaselString(Apollo.GetString("Guild_NewsListItem"), self:HelperRelativeTimeToString(tEventLog.fCreationTime), strMessage)
end

-----------------------------------------------------------------------------------------------
-- Buttons
-----------------------------------------------------------------------------------------------

function GuildInfo:OnGuildTaxOn(wndHandler, wndControl)
	local guildOwner = self.wndMain:GetData()
	if not guildOwner then
		return
	end

	local tLocalTable =
	{
		bTax = true
	}
	guildOwner:SetFlags(tLocalTable)
	self.tWndRefs.wndGuildMemberGuildTaxLabel:SetText(String_GetWeaselString(Apollo.GetString("Guild_GuildTaxLabel"), Apollo.GetString("MatchMaker_FlagOn")))
end

function GuildInfo:OnGuildTaxOff(wndHandler, wndControl)
	local guildOwner = self.wndMain:GetData()
	if not guildOwner then
		return
	end

	local tLocalTable =
	{
		bTax = false
	}
	guildOwner:SetFlags(tLocalTable)
	self.tWndRefs.wndGuildMemberGuildTaxLabel:SetText(String_GetWeaselString(Apollo.GetString("Guild_GuildTaxLabel"), Apollo.GetString("MatchMaker_FlagOff")))
end

function GuildInfo:OnMotDEditClick(wndHandler, wndControl)
	local guildOwner = self.wndMain:GetData()
	if not guildOwner then
		return
	end

	if wndHandler:IsChecked() then
		self.wndMain:FindChild("EditMotDEditBox"):SetText(guildOwner:GetMessageOfTheDay())
		self.wndMain:FindChild("EditMotDEditBox"):SetFocus()
	end

	self:HelperValidateMotdEdit()
end

function GuildInfo:OnEditMotDCloseBtn() -- The Window Close Event can also route here
	self.wndMain:FindChild("EditMotDEditBox"):SetText("")
	self.wndMain:FindChild("EditMOTD"):Show(false)

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

	if wndHandler:IsChecked() then
		self.wndMain:FindChild("EditInfoEditBox"):SetText(guildOwner:GetInfoMessage())
		self.wndMain:FindChild("EditInfoEditBox"):SetFocus()
	end

	self:HelperValidateInfoEdit()
end

function GuildInfo:OnEditInfoCloseBtn() -- The Window Close Event can also route here
	self.wndMain:FindChild("EditInfoEditBox"):SetText("")
	self.wndMain:FindChild("EditAdditionalInfo"):Show(false)

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
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:GetData() == guildOwner then
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
	
	local wndNewsGrid = self.tWndRefs.wndNewsGrid
	
	wndNewsGrid:DeleteAll()
	
	for idx, tEventLog in pairs(guildUpdated:GetEventLogs()) do
		local strText = self:GetNewsListItemText(tEventLog, idx)
		if strText ~= nil then
			local iCurrRow = wndNewsGrid:AddRow("", "CRB_Basekit:kitIcon_Gold_Exclamation")
			wndNewsGrid:SetCellDoc(iCurrRow, 2, '<T Font="CRB_InterfaceSmall" TextColor="WindowTitleColor">'.. strText .."</T>")
		end
	end
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
	if guildUpdated and guildUpdated:GetChannel() then
		guildUpdated:GetChannel():Post(Apollo.GetString("Guild_FlagsChanged"))
	end
end

function GuildInfo:OnGuildName(guildUpdated)
	if guildUpdated and guildUpdated:GetChannel() then
		guildUpdated:GetChannel():Post(String_GetWeaselString(Apollo.GetString("Guild_NameChanged"), guildUpdated:GetName() ))
	end
end

function GuildInfo:OnNewsExpand()
	local nLeftMotD, nTopMotD, nRightMotD, nBottomMotD = self.wndMain:FindChild("InfoPaneLabel1"):GetAnchorOffsets()
	local nLeftInfo, nTopInfo, nRightInfo, nBottomInfo = self.wndMain:FindChild("InfoPaneLabel2"):GetAnchorOffsets()
	local nLeftNews, nTopNews, nRightNews, nBottomNews = self.wndMain:FindChild("NewsFraming"):GetAnchorOffsets()
	local nBottomNewsStuckToBottom = nBottomNews --Saving initial bottom anchor before it's changed
	self.wndMain:FindChild("InfoPaneLabel1"):SetAnchorOffsets(nLeftMotD, nTopMotD, nRightMotD, nTopMotD + 35)
	self.wndMain:FindChild("InfoPaneLabel2"):SetAnchorOffsets(nLeftInfo, nTopInfo, nRightInfo, nTopInfo + 35)
	self.wndMain:FindChild("NewsPane"):ArrangeChildrenVert(0)
	
	local nLeftNews2, nTopNews2, nRightNews2, nBottomNews2 = self.wndMain:FindChild("NewsFraming"):GetAnchorOffsets() -- This needs to run AFTER ArrangeChildren
	self.wndMain:FindChild("NewsFraming"):SetAnchorOffsets(nLeftNews2, nTopNews2, nRightNews2, nBottomNewsStuckToBottom)
end

function GuildInfo:OnNewsCollapse()
	local nLeftMotD, nTopMotD, nRightMotD, nBottomMotD = self.wndMain:FindChild("InfoPaneLabel1"):GetAnchorOffsets()
	local nLeftInfo, nTopInfo, nRightInfo, nBottomInfo = self.wndMain:FindChild("InfoPaneLabel2"):GetAnchorOffsets()
	local nLeftNews, nTopNews, nRightNews, nBottomNews = self.wndMain:FindChild("NewsFraming"):GetAnchorOffsets()
	local nBottomNewsStuckToBottom = nBottomNews --Saving initial bottom anchor before it's changed
	self.wndMain:FindChild("InfoPaneLabel1"):SetAnchorOffsets(nLeftMotD, nTopMotD, nRightMotD, nTopMotD + 120)
	self.wndMain:FindChild("InfoPaneLabel2"):SetAnchorOffsets(nLeftInfo, nTopInfo, nRightInfo, nTopInfo + 120)
	self.wndMain:FindChild("NewsPane"):ArrangeChildrenVert(0)
	
	local nLeftNews2, nTopNews2, nRightNews2, nBottomNews2 = self.wndMain:FindChild("NewsFraming"):GetAnchorOffsets()-- This needs to run AFTER ArrangeChildren
	self.wndMain:FindChild("NewsFraming"):SetAnchorOffsets(nLeftNews2, nTopNews2, nRightNews2, nBottomNewsStuckToBottom)
end

local GuildInst = GuildInfo:new()
GuildInst:Init()
