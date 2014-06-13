-----------------------------------------------------------------------------------------------
-- Client Lua Script for ReportPlayer
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "GroupLib"
require "ChatSystemLib"
require "FriendshipLib"
require "MailSystemLib"

-----------------------------------------------------------------------------------------------
-- Report Setup
-----------------------------------------------------------------------------------------------

local ReportPlayer = {}

function ReportPlayer:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function ReportPlayer:Init()
    Apollo.RegisterAddon(self)
end

function ReportPlayer:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("ReportPlayer.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function ReportPlayer:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end

	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerChat", 			"OnReportPlayerChat", self) -- 1 arg
	Apollo.RegisterEventHandler("GenericEvent_ReportPlayerMail", 			"OnReportPlayerMail", self) -- 1 arg
end

-----------------------------------------------------------------------------------------------
-- Report Chat 
-----------------------------------------------------------------------------------------------

function ReportPlayer:OnReportPlayerChat(nReportId)
	if nReportId == nil then
		return
	end
	
	local tResult = ChatSystemLib.PrepareInfractionReport(self.nReportId)
	self:BuildReportConfirmation(tResult.strDescription, tResult.bSuccess, ChatSystemLib.SendInfractionReport)
end

-----------------------------------------------------------------------------------------------
-- Report Mail
-----------------------------------------------------------------------------------------------

function ReportPlayer:OnReportPlayerMail(msgMail)
	if not MailSystemLib.is(msgMail) then
		return
	end

	local tResult = msgMail:PrepareInfractionReport()
	self:BuildReportConfirmation(tResult.strDescription, tResult.bSuccess, MailSystemLib.SendInfractionReport)
end

-----------------------------------------------------------------------------------------------
-- Report Confirmation
-----------------------------------------------------------------------------------------------

function ReportPlayer:BuildReportConfirmation(strMessage, bYesNo, funcYesOperation)
	if not strMessage then return end
	self:ClearReportConfirmation()

	self.funcYesOperation = funcYesOperation

	local wndCurr = Apollo.LoadForm(self.xmlDoc, "ReportPlayer_YesNo", nil, self)
	if bYesNo then
		wndCurr:FindChild("CancelButton"):Show(false)
		wndCurr:FindChild("YesButton"):Show(true)
		wndCurr:FindChild("NoButton"):Show(true)
	else
		wndCurr:FindChild("CancelButton"):Show(true)
		wndCurr:FindChild("YesButton"):Show(false)
		wndCurr:FindChild("NoButton"):Show(false)
	end

	wndCurr:FindChild("BodyText"):SetTextRaw(strMessage)

	self.wndChatReport = wndCurr
end

function ReportPlayer:ClearReportConfirmation()
	if self.wndChatReport then
		self.wndChatReport:Destroy()
		self.wndChatReport = nil
		self.funcYesOperation = nil
	end
end

function ReportPlayer:ReportChat_WindowClosed(wndHandler)
	self:ClearReportConfirmation()
end

function ReportPlayer:ReportChat_NoPicked(wndHandler, wndControl)
	self:ClearReportConfirmation()
end

function ReportPlayer:ReportChat_YesPicked(wndHandler, wndControl)
	if self.funcYesOperation then
		self.funcYesOperation()
	end
	self:ClearReportConfirmation()
end


local ReportPlayerInst = ReportPlayer:new()
ReportPlayerInst:Init()
