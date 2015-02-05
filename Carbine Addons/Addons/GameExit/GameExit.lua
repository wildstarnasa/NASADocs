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
	self.timerGameExit = ApolloTimer.Create(0.5, true, "OnTimer", self)

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
		self.wndMain:Close()
		return
	elseif tExitInfo.ePendingEvent == GameLib.CodeEnumExitEvent.Quit then
		self.wndMain:FindChild("Title"):SetText(Apollo.GetString("CRB_Exit"))
		self.wndMain:FindChild("Message"):SetText(Apollo.GetString("GameExit_TimeTillQuit"))
		self.wndMain:FindChild("LeaveNow"):Show(true)
		self.wndMain:FindChild("CancelButton"):SetAnchorOffsets(211, -91, 351, -18)
	else
		self.wndMain:FindChild("Title"):SetText(Apollo.GetString("Options_SwitchCharacter"))
		self.wndMain:FindChild("Message"):SetText(Apollo.GetString("GameExit_TimeTillCamp"))
		self.wndMain:FindChild("LeaveNow"):Show(false)
		self.wndMain:FindChild("CancelButton"):SetAnchorOffsets(136, -91, 276, -18)
	end
	
	if not self.wndMain:IsShown() then
		self.wndMain:Invoke()
	end
	
	self.wndMain:FindChild("Time"):SetText(String_GetWeaselString(Apollo.GetString("GameExit_Timer"), tExitInfo.fTimeRemaining))

	-- TODO: Do this the right way when there's time
	local nSeconds = math.floor(tExitInfo.fTimeRemaining)
	local strOutput = nSeconds < 10 and Apollo.GetString("GameExit_ShortTimer") or Apollo.GetString("GameExit_NumTimer")
	self.wndMain:FindChild("Time"):SetText(String_GetWeaselString(strOutput, nSeconds))
end

function GameExit:OnPlayerCamp()
	self.wndMain:Invoke()
	self.wndMain:FindChild("Title"):SetText(Apollo.GetString("Options_SwitchCharacter"))
	self.wndMain:FindChild("Message"):SetText(Apollo.GetString("GameExit_TimeTillCamp"))
end

function GameExit:OnPlayerExit()
	self.wndMain:Invoke()
	self.wndMain:FindChild("Title"):SetText(Apollo.GetString("CRB_Exit"))
	self.wndMain:FindChild("Message"):SetText(Apollo.GetString("GameExit_TimeTillQuit"))
end

-----------------------------------------------------------------------------------------------
-- GameExitForm Functions
-----------------------------------------------------------------------------------------------

function GameExit:OnCancel(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	self.wndMain:Close()
	CancelExit()
end

function GameExit:OnLeaveNow( wndHandler, wndControl, eMouseButton )
	ExitNow()
end

local GameExitInst = GameExit:new()
GameExitInst:Init()
et="66" DT_VCENTER="1" DT_CENTER="1" BGColor="UI_BtnBGDefault" TextColor="UI_BtnTextDefault" NormalTextColor="UI_BtnTextDefault" PressedTextColor="UI_BtnTextDefault" FlybyTextColor="UI_BtnTextDefault" PressedFlybyTextColor="UI_BtnTextDefault" DisabledTextColor="UI_BtnTextDefault" TooltipType="OnCursor" Name="DockBtn" TooltipColor="" TestAlpha="1" DrawAsCheckbox="0"