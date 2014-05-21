-----------------------------------------------------------------------------------------------
-- Client Lua Script for InstanceSettings
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

local LuaCodeEnumDifficultyTypes =
{
	Normal = 1,
	Veteran = 2,
	Unset = 3,
}

local InstanceSettings = {}

--local knSaveVersion = 1

function InstanceSettings:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	
	self.bHidingInterface = false
	self.bNormalIsAllowed = false
	self.bVeteranIsAllowed = false

	self.bScalingIsAllowed = false
	
    return o
end

function InstanceSettings:Init()
    Apollo.RegisterAddon(self)
end

function InstanceSettings:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local locMainWindowLoc = self.wndMain and self.wndMain:GetLocation() or self.locSavedMainLoc
	local locRestrictedWindowLoc = self.wndWaiting and self.wndWaiting:GetLocation() or self.locSavedRestrictedLoc
	
	local tSaved = 
	{
		tMainLocation = locMainWindowLoc and locMainWindowLoc:ToTable() or nil,
		tWaitingLocation = locRestrictedWindowLoc and locRestrictedWindowLoc:ToTable() or nil,
		nSavedVersion = knSaveVersion
	}
	
	return tSaved
end

function InstanceSettings:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSavedVersion ~= knSaveVersion then
		return
	end
	if tSavedData.tMainLocation then
		self.locSavedMainLoc = WindowLocation.new(tSavedData.tMainLocation)
	end
	
	if tSavedData.tWaitingLocation then
		self.locSavedRestrictedLoc = WindowLocation.new(tSavedData.tWaitingLocation)
	end
end

function InstanceSettings:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("InstanceSettings.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function InstanceSettings:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("ShowInstanceGameModeDialog", "OnShowDialog", self)
	Apollo.RegisterEventHandler("ShowInstanceRestrictedDialog", "OnShowRestricted", self)
	Apollo.RegisterEventHandler("HideInstanceGameModeDialog", "OnHideDialog", self)
	Apollo.RegisterEventHandler("OnInstanceResetResult", "OnInstanceResetResult", self)
	Apollo.RegisterEventHandler("PendingWorldRemovalWarning", "OnPendingWorldRemovalWarning", self)
	Apollo.RegisterEventHandler("PendingWorldRemovalCancel", "OnPendingWorldRemovalCancel", self)
	Apollo.RegisterEventHandler("ChangeWorld", "OnChangeWorld", self)
	
	Apollo.RegisterTimerHandler("InstanceSettings_MessageDisplayTimer", "OnMessageDisplayTimer", self)
	Apollo.RegisterTimerHandler("InstanceSettings_PendingRemovalTimer", "OnPendingRemovalTimer", self)
	
	self:OnPendingWorldRemovalWarning()
end

function InstanceSettings:OnShowRestricted()
	self:DestroyAll()
	self.wndWaiting = Apollo.LoadForm(self.xmlDoc , "InstanceSettingsRestrictedForm", nil, self)
	
	if self.locSavedRestrictedLoc then
		self.wndWaiting:MoveToLocation(self.locSavedRestrictedLoc)
	end
end

function InstanceSettings:OnShowDialog(tData)
	self:DestroyAll()

	self.bNormalIsAllowed = tData.bDifficultyNormal
	self.bVeteranIsAllowed = tData.bDifficultyVeteran
	self.bScalingIsAllowed = tData.bFlagsScaling

	self.wndMain = Apollo.LoadForm(self.xmlDoc , "InstanceSettingsForm", nil, self)
	self.bHidingInterface = false
		
	-- we never want to show this "error" initially
	self.wndMain:FindChild("ErrorWindow"):Show(false)

	-- we always "show" based on flags
	self.wndMain:FindChild("LevelScalingButton"):Show(self.bScalingIsAllowed)
	
	-- start off w/ scaling/rallying off
	self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Rallying", 0)
	
	if self.locSavedMainLoc then
		self.wndMain:MoveToLocation(self.locSavedMainLoc)
	end

	if tData.nExistingDifficulty == GroupLib.Difficulty.Count then
		-- there is no existing instance
		self:OnNoExistingInstance()
		
	else
		-- an existing instance

		-- set the options above to the settings of that instance (and disable the ability to change them)
		if tData.nExistingDifficulty == GroupLib.Difficulty.Normal then
			self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Difficulty", LuaCodeEnumDifficultyTypes.Normal)
		else
			self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Difficulty", LuaCodeEnumDifficultyTypes.Veteran)
		end

		if tData.bExistingScaling == false then
			self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Rallying", 0)
		else
			self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Rallying", 1)
		end

		self.wndMain:FindChild("DifficultyButton1"):Enable(false)
		self.wndMain:FindChild("DifficultyButton2"):Enable(false)
		self.wndMain:FindChild("LevelScalingButton"):Enable(false)

		self.wndMain:FindChild("ExistingFrame"):Show(true)
		self.wndMain:FindChild("ResetInstanceButton"):Show(true)
		self.wndMain:FindChild("Divider"):Show(true)

		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 615)

	end

end

function InstanceSettings:OnInstanceResetResult(bResetWasSuccessful)

	if self.wndMain:IsShown() then
		Apollo.StopTimer("InstanceSettings_MessageDisplayTimer")
		
		-- dialog may have been destroyed ... so we have to check windows here
		local errorWindow = self.wndMain:FindChild("ErrorWindow")
		if errorWindow then
			if bResetWasSuccessful == true then
				self:OnNoExistingInstance()
			else
				errorWindow:Show(true)
				Apollo.CreateTimer("InstanceSettings_MessageDisplayTimer", 4, false)
			end
		end
	end
end

function InstanceSettings:OnExitInstance()
	GameLib.LeavePendingRemovalInstance()
end

function InstanceSettings:OnPendingWorldRemovalWarning()
	local nRemaining = GameLib.GetPendingRemovalWarningRemaining()
	if nRemaining > 0 then
		self:DestroyAll()
		self.wndPendingRemoval = Apollo.LoadForm(self.xmlDoc , "InstanceSettingsPendingRemoval", nil, self)
		self.wndPendingRemoval:FindChild("RemovalCountdownLabel"):SetText(nRemaining)
		self.wndPendingRemoval:SetData(nRemaining)
		Apollo.CreateTimer("InstanceSettings_PendingRemovalTimer", 1, true)
	end	
end

function InstanceSettings:OnPendingWorldRemovalCancel()
	if self.wndPendingRemoval then
		self.wndPendingRemoval:Destroy()
	end
	Apollo.StopTimer("InstanceSettings_PendingRemovalTimer")
end

function InstanceSettings:OnMessageDisplayTimer()
	if self.wndMain:IsShown() then
		-- dialog may have been destroyed ... so we have to check windows here
		local errorWindow = self.wndMain:FindChild("ErrorWindow")
		if errorWindow then
			errorWindow:Show(false)
			self.wndMain:FindChild("ResetInstanceButton"):Enable(true)
			self.wndMain:FindChild("EnterButton"):Enable(true)
		end
	
	end
end

function InstanceSettings:OnPendingRemovalTimer()
	if self.wndPendingRemoval then
		local nRemaining = self.wndPendingRemoval:GetData()
		nRemaining = nRemaining - 1
		self.wndPendingRemoval:FindChild("RemovalCountdownLabel"):SetText(nRemaining)
		self.wndPendingRemoval:SetData(nRemaining)
	end
end

function InstanceSettings:OnNoExistingInstance()

	-- difficulty settings
	self.wndMain:FindChild("DifficultyButton1"):Enable(self.bNormalIsAllowed)
	self.wndMain:FindChild("DifficultyButton2"):Enable(self.bVeteranIsAllowed)
	
	if self.bNormalIsAllowed then
		self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Difficulty", LuaCodeEnumDifficultyTypes.Normal)
	else
		self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Difficulty", 0)
	end
	
	-- scaling settings
	if 	self.bScalingIsAllowed then
		self.wndMain:FindChild("LevelScalingButton"):Enable(true)
		self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Rallying", 1)
	else
		self.wndMain:FindChild("LevelScalingButton"):Enable(false)
		self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Rallying", 0)
	end

	-- turn on the enter button
	self.wndMain:FindChild("EnterButton"):Enable(true)

	self.wndMain:FindChild("ResetInstanceButton"):Show(false)
	self.wndMain:FindChild("ExistingFrame"):Show(false)
	self.wndMain:FindChild("Divider"):Show(false)
	
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 425)

end

function InstanceSettings:OnOK()
	local eDifficulty = nil
	if LuaCodeEnumDifficultyTypes.Veteran == self.wndMain:GetRadioSel("InstanceSettings_LocalRadioGroup_Difficulty") then
		eDifficulty = GroupLib.Difficulty.Veteran
	else 
		eDifficulty = GroupLib.Difficulty.Normal
	end
	
	GameLib.SetInstanceSettings(eDifficulty, self.wndMain:GetRadioSel("InstanceSettings_LocalRadioGroup_Rallying"))
	self:DestroyAll()
end

function InstanceSettings:OnReset()
	self.wndMain:FindChild("ResetInstanceButton"):Enable(false)
	self.wndMain:FindChild("EnterButton"):Enable(false)
	GameLib.ResetSingleInstance()
end

function InstanceSettings:OnHideDialog(bNeedToNotifyServer)
	if self.bHidingInterface == false then
		self.bHidingInterface = true
		GameLib.OnClosedInstanceSettings(bNeedToNotifyServer)
		self:DestroyAll()
	end
end

function InstanceSettings:OnCancel()
	self:OnHideDialog(true) -- we must tell the server about this 
end

function InstanceSettings:OnChangeWorld()
	self:OnPendingWorldRemovalWarning()
end

function InstanceSettings:DestroyAll()
	if self.wndMain and self.wndMain:IsValid() then
		self.locSavedMainLoc = self.wndMain:GetLocation()
		self.wndMain:Destroy()
	end

	if self.wndWaiting and self.wndWaiting:IsValid() then
		self.locSavedWatingLoc = self.wndWaiting:GetLocation()
		self.wndWaiting:Destroy()
	end
end

local InstanceSettingsInst = InstanceSettings:new()
InstanceSettingsInst:Init()
