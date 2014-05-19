-----------------------------------------------------------------------------------------------
-- Client Lua Script for GameExit
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local GameExit = {}

function GameExit:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function GameExit:Init()
    Apollo.RegisterAddon(self)
end

function GameExit:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("GameExit.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function GameExit:OnDocumentReady()
	Apollo.RegisterSlashCommand("camp", "OnCampSlashCommand", self)
	Apollo.RegisterEventHandler("GenericEvent_PlayerCampStart", "OnPlayerCamp", self)
	Apollo.RegisterEventHandler("GenericEvent_PlayerExitStart", "OnPlayerExit", self)
	Apollo.RegisterEventHandler("GenericEvent_PlayerExitCancel", "OnCancel", self)
    Apollo.RegisterTimerHandler("HalfSecTimer", "OnTimer", self)

	Apollo.CreateTimer("HalfSecTimer", 0.50, true)

    -- load our forms
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "GameExitForm", "TooltipStratum", self)
    self.wndMain:Show(false)
	self.xmlDoc = nil
end

function GameExit:OnCampSlashCommand()
	self:OnPlayerCamp()
	Camp()
end

function GameExit:OnTimer()
	if IsDemo() then
		ExitNow()
		return
	end

	local tExitInfo = GameLib.GetGameExitInfo()
	if tExitInfo.ePendingEvent == GameLib.CodeEnumExitEvent.None then
		self.wndMain:Show(false)
		return
	elseif tExitInfo.ePendingEvent == GameLib.CodeEnumExitEvent.Quit then
		self.wndMain:FindChild("Title"):SetText(Apollo.GetString("CRB_Exit"))
		self.wndMain:FindChild("Message"):SetText(Apollo.GetString("GameExit_TimeTillQuit"))
		self.wndMain:FindChild("LeaveNow"):Show(true)

		self.wndMain:FindChild("CancelButton"):SetAnchorOffsets(0, -91, 200, -18)
	else
		self.wndMain:FindChild("Title"):SetText(Apollo.GetString("Options_SwitchCharacter"))
		self.wndMain:FindChild("Message"):SetText(Apollo.GetString("GameExit_TimeTillCamp"))
		self.wndMain:FindChild("LeaveNow"):Show(false)

		self.wndMain:FindChild("CancelButton"):SetAnchorOffsets(-100, -91, 100, -18)
			end
	self.wndMain:Show(true)
	self.wndMain:FindChild("Time"):SetText(String_GetWeaselString(Apollo.GetString("GameExit_Timer"), tExitInfo.fTimeRemaining))

	-- TODO: Do this the right way when there's time
	local nSeconds = math.floor(tExitInfo.fTimeRemaining)
	local strOutput = nSeconds < 10 and Apollo.GetString("GameExit_ShortTimer") or Apollo.GetString("GameExit_NumTimer")
	self.wndMain:FindChild("Time"):SetText(String_GetWeaselString(strOutput, nSeconds))
end

function GameExit:OnPlayerCamp()
	self.wndMain:Show(true)
	self.wndMain:FindChild("Title"):SetText(Apollo.GetString("Options_SwitchCharacter"))
	self.wndMain:FindChild("Message"):SetText(Apollo.GetString("GameExit_TimeTillCamp"))
end

function GameExit:OnPlayerExit()
	self.wndMain:Show(true)
	self.wndMain:FindChild("Title"):SetText(Apollo.GetString("CRB_Exit"))
	self.wndMain:FindChild("Message"):SetText(Apollo.GetString("GameExit_TimeTillQuit"))
end

-----------------------------------------------------------------------------------------------
-- GameExitForm Functions
-----------------------------------------------------------------------------------------------

function GameExit:OnPreOrder()
	GameLib.InvokePreOrder()
	ExitNow()
end

function GameExit:OnCancel()
	self.wndMain:Show(false)
	CancelExit()
end

function GameExit:OnLeaveNow( wndHandler, wndControl, eMouseButton )
	ExitNow()
end

local GameExitInst = GameExit:new()
GameExitInst:Init()
