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
	self.wndMain:FindChild("LevelScalingButton"):Enable(true)
	self.wndMain:FindChild("LevelScalingButton"):Show(true)
	self.wndMain:FindChild("ContentFrameScaling"):Show(true)
	self.wndMain:FindChild("ScalingIsForced"):Show(false)
	-- we never want to show this "error" initially
	self.wndMain:FindChild("ErrorWindow"):Show(false)

	
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
			self.wndMain:FindChild("ContentFrame"):SetRadioSel("InstanceSettings_LocalRadioGroup_Rallying", 0)
		else
			self.wndMain:FindChild("ContentFrame"):SetRadioSel("InstanceSettings_LocalRadioGroup_Rallying", 1)
		end

		self.wndMain:FindChild("DifficultyButton1"):Show(false)
		self.wndMain:FindChild("DifficultyButton2"):Show(false)
		self.wndMain:FindChild("ContentFrame"):Show(false)
		self.wndMain:FindChild("TitleBlock"):SetText(Apollo.GetString("InstanceSettings_Exists"))
		self.wndMain:FindChild("ExistingInstanceSettings"):Show(true)
		self.wndMain:FindChild("ResetInstanceButton"):Show(true)
		
		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 330)
	
		if tData.nExistingDifficulty == GroupLib.Difficulty.Normal then
			self.wndMain:FindChild("DifficultyNormalCallout"):SetText(Apollo.GetString("CRB_Difficulty") .. " " .. Apollo.GetString("Tooltips_Normal"))
		else 
			self.wndMain:FindChild("DifficultyNormalCallout"):SetText(Apollo.GetString("CRB_Difficulty") .. " " .. Apollo.GetString("MiniMap_Veteran"))
		end
			
		if tData.bExistingScaling then
			self.wndMain:FindChild("Rally"):SetText(Apollo.GetString("InstanceSettings_Level149_Title") .. " " .. Apollo.GetString("CRB_Yes"))
		else
			self.wndMain:FindChild("Rally"):SetText(Apollo.GetString("InstanceSettings_Level149_Title") .. " " .. Apollo.GetString("CRB_No"))
		end

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
	if self.wndMain and self.wndMain:IsValid() and self.wndMain:IsShown() then
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
	elseif self.bVeteranIsAllowed then
		self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Difficulty", LuaCodeEnumDifficultyTypes.Veteran)
		self:DisableRally()
	else
		self.wndMain:SetRadioSel("InstanceSettings_LocalRadioGroup_Difficulty", 0)
	end
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	-- scaling settings
	if self.bScalingIsAllowed then
		self.wndMain:FindChild("ContentFrame"):SetRadioSel("InstanceSettings_LocalRadioGroup_Rallying", 1)
		self:EnableRally()
		self.wndMain:FindChild("LevelScalingButton"):Enable(true)
		self.wndMain:FindChild("LevelScalingButton"):Show(true)
	else
		self:DisableRally()
		self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 295)
		self.wndMain:FindChild("LevelScalingButton"):Show(false)
		self.wndMain:FindChild("ContentFrameScaling"):Show(false)

	end
	
	self.wndMain:FindChild("EnterButton"):Enable(self.bNormalIsAllowed or self.bVeteranIsAllowed)
	self.wndMain:FindChild("DifficultyNormalCallout"):Show(false)
	self.wndMain:FindChild("ContentFrame"):Show(true)
	self.wndMain:FindChild("DifficultyButton1"):Show(true)
	self.wndMain:FindChild("DifficultyButton2"):Show(true)
	self.wndMain:FindChild("TitleBlock"):SetText(Apollo.GetString("InstanceSettings_Title"))
	self.wndMain:FindChild("ResetInstanceButton"):Show(false)
	self.wndMain:FindChild("ExistingInstanceSettings"):Show(false)
end

function InstanceSettings:OnOK()
	local eDifficulty = nil
	local nRally = self.wndMain:FindChild("ContentFrame"):GetRadioSel("InstanceSettings_LocalRadioGroup_Rallying")
	if LuaCodeEnumDifficultyTypes.Veteran == self.wndMain:GetRadioSel("InstanceSettings_LocalRadioGroup_Difficulty") then
		eDifficulty = GroupLib.Difficulty.Veteran
		nRally = 0
	else 
		eDifficulty = GroupLib.Difficulty.Normal
	end

	GameLib.SetInstanceSettings(eDifficulty, nRally)
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
		self.wndMain = nil
	end

	if self.wndWaiting and self.wndWaiting:IsValid() then
		self.locSavedWatingLoc = self.wndWaiting:GetLocation()
		self.wndWaiting:Destroy()
		self.wndWaiting = nil
	end
end

function InstanceSettings:EnableRally( wndHandler, wndControl, eMouseButton )
	if self.bScalingIsAllowed then
		self.wndMain:FindChild("LevelScalingButton"):Enable(true)
		self.wndMain:FindChild("LevelScalingButton"):Show(true)
		self.wndMain:FindChild("ContentFrameScaling"):Show(true)
		self.wndMain:FindChild("ScalingIsForced"):Show(false)
		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 343)
	end
end

function InstanceSettings:DisableRally( wndHandler, wndControl, eMouseButton )
	if self.bScalingIsAllowed then
		self.wndMain:FindChild("LevelScalingButton"):Show(false)
		self.wndMain:FindChild("ContentFrameScaling"):Show(true)
		self.wndMain:FindChild("ScalingIsForced"):Show(true)
		local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
		self.wndMain:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 343)
	end
end

local InstanceSettingsInst = InstanceSettings:new()
InstanceSettingsInst:Init()

qÿ
‹ÿ½ÿ|ösÿÿÿ°ÿ<ÿ-ÿÕÿ¶ÿ½ÿÑÿØÿÑÿpÿu
ÿo	ÿv
ÿÿÜÿåÿçÿ!åÿ Ëÿ¢ÿƒ
ÿsÿbÿZÿ[ÿ`ÿmÿ²ÿÜÿãÿİ(ÿ›ÿ ÿ»ÿEÒAÿœé‚ÿÂÿ¢ÿÿÿxÿDÍ/ÿ+– ÿƒÿPÿ=	ÿ1ÿ%ÿÿÿÿÿÿÿ	ÿÿÿÿ ÿ$ÿDÿ	jÿ
wÿ	oÿ_ÿoÿ—ÿ,Ò,ÿŒö‹ÿŸÿtÿîÿÂÿ»ÿÈÿÑÿÔÿ¿ÿy
ÿv
ÿ}
ÿªÿåÿ ñÿ#Óÿ†ÿ^ÿQÿOÿPÿSÿWÿ[ÿ`ÿ_ÿ}ÿÄÿÑÿ×.ÿÃÿà ÿÜÿ‹êtÿåÿB½3ÿÿÂÿ‡ÿWÿA	ÿ4ÿ*ÿÿÿÿÿÿÿÿÿÿÿÿÿFÿ†ÿ¢	ÿ/×Nÿ%Ê9ÿ
vÿ`ÿ	~ÿ¹ÿTáWÿ¡ÿ”ÿhÿRÿ:Û4ÿhß\ÿ=Ó/ÿÄÿ›	ÿ™ÿ³ÿ£ÿ´ÿÖÿìÿËÿnÿQÿVÿZÿ[ÿ\ÿ[ÿ_ÿ\ÿgÿjÿ…ÿËÿÍÿ¶ÿ©ÿÏÿqÿRÿ›ê‚ÿPÇ=ÿ—ÿ
vÿ	fÿ_ÿE	ÿ8ÿ0ÿ#ÿÿÿÿÿÿÿÿÿÿÿÿ?ÿ…ÿ–ÿ4Ü^ÿ>ítÿ=ísÿˆÿSÿiÿ ÿÏ!ÿ|îÿÿÿ±ÿø}ÿ©ÿÿùÿšÿHÿ2ÿ³ÿ‘ÿ{ÿ}
ÿ‹	ÿ¿	ÿéÿ	ÿTÿ^ÿeÿgÿdÿ`ÿ[ÿ\ÿnÿmÿ”	ÿÆÿ¼ÿ¢	ÿ–
ÿ­ÿDİ-ÿÖÿ”ÿoÙWÿ›ÿ	xÿ	eÿUÿF	ÿ:ÿLÿ 
ÿQÿÿÿÿÿÿÿÿÿÿÿ'ÿ	[ÿ	ÿ&¹=ÿ>ìvÿ8äfÿ1İSÿlÿLÿX	ÿ‹ÿÇÿkénÿàÿªÿ¢ÿ…ÿmÿTÿsócÿ¥ÿ‰ÿ«ÿlÿ"Éÿ­	ÿÿqÿ›ÿäÿ¯ÿ`ÿZÿ^ÿ^ÿXÿYÿjÿ{
ÿÿÁÿÓÿ·ÿ¨
ÿ±
ÿ·ÿ,Ìÿ¦ıˆÿøÿ¢ÿ&½ÿ
~ÿ	gÿVÿH	ÿ9ÿ1ÿ-ÿ„	ÿ	cÿÿÿÿ%ÿ2ÿ
)ÿÿ!ÿÿÿ0ÿeÿ	ÿ!®2ÿ:älÿ.ÕNÿªÿJÿCÿNÿ
z
ÿ(Áÿƒíqÿµÿ‘ÿjÿMÿÁÿÊ!ÿhë\ÿ˜ü†ÿÀÿ„ÿ;ì(ÿ·
ÿ•	ÿ	ÿÂÿĞÿ¨ÿzÿo
ÿxÿ†ÿ–ÿ¤ÿÅÿÙÿÎÿ	ºÿ¹ÿ!Çÿ3Ğ&ÿFä/ÿÁÿŠÿøÿ¯ÿ˜ÿiÿƒÿfÿVÿR	ÿPÿ1ÿ(ÿÿÿÿÿÿ"ÿHÿJÿHÿ5
ÿ ÿÿÿ,ÿ	Vÿ‰ÿ“	ÿ›	ÿ›	ÿ
_ÿ9ÿ>ÿHÿ	cÿ$£ÿ3Í+ÿ$ÿ!ÿ´ÿœÿŸÿ¹ÿ4Ø2ÿnû\ÿÉÿ‡ÿ|õdÿ>Õ.ÿ½ÿ·ÿ#ğÿ1ù0ÿÂÿ½ÿÃÿÌÿÏÿĞÿÌÿÈÿ(Ë"ÿFØ;ÿqècÿµÿŒÿôÿ—ÿÓÿ‚ÿ§ı|ÿ‘äpÿ†ÿbÿTÿKÿÿ±ÿŒ	ÿ	Vÿÿÿÿÿÿ.ÿKÿMÿKÿG
ÿÿÿÿÿ;ÿMÿgÿ
fÿ>ÿ0ÿ7ÿ;ÿ@ÿKÿjÿ
…ÿ‘ÿ	ˆÿ
‹ÿ
ÿ–ÿ§ÿÀÿ?á8ÿùÿ–ÿ—ÿzÿ-Ø'ÿÿÿÿXÿÅÿÿÅÿºÿ½ÿÂÿÇÿ+Í%ÿIÙ=ÿêmÿ­ÿÿÒÿ˜ÿäÿ–ÿ£ÿsÿ^ÚIÿ/°&ÿ‰ÿnÿ]ÿN
ÿD	ÿ;ÿ€	ÿ±ÿ)ÇBÿÿ
Pÿÿÿÿÿ
(ÿKÿLÿLÿJ
ÿÿÿÿÿÿ%ÿ'ÿÿ$ÿ)ÿ/ÿLÿzÿ]ÿKÿZÿfÿrÿ	~ÿ
ˆÿ
ÿÿ™ÿ¯ÿ?å6ÿÅÿ…ÿ¡ÿyÿ€ÿYÿ€îhÿ“ÿrÿÃÿsÿàÿ'Ï%ÿXÜNÿƒé{ÿöŠÿ¶ÿÿÜÿ–ÿ±ÿuÿXñAÿ!Åÿ ÿ
ˆÿqÿ`
ÿS
ÿK	ÿ=ÿ4ÿ+ÿCÿ˜ÿ(¾Aÿ¢"ÿwÿ ÿÿÿÿÿEÿKÿJÿG
ÿÿÿÿÿÿÿÿÿÿ#ÿ3ÿŸ
ÿ¹ÿ¬	ÿEÿGÿ3ÿ*
ÿ2ÿJÿ
„ÿ
†ÿ
‰ÿÿ—ÿ0Ã/ÿÿÿ‹ÿ{òdÿ-À+ÿ8Ë2ÿ•ûÿ¿ÿÿšÿ|ÿŠî{ÿ•ÿtÿÿ`ÿTñ?ÿºÿ§ÿ–ÿ
ÿ	lÿ\
ÿS	ÿKÿ>ÿ7ÿ3ÿ&ÿ!ÿÿAÿsÿ}	ÿ	Rÿÿÿÿÿÿÿ;ÿ?ÿ0
ÿÿÿÿ.ÿQ&ÿÿÿÿÿ ÿ&ÿoÿ£	ÿxÿ7ÿÿ
ÿÿÿ%ÿ	wÿ	{ÿ
~ÿ	~ÿ
€ÿ‚ÿL»Gÿ$³(ÿ•ÿ¥ÿgÒZÿ~Ûmÿ_üFÿ4ú%ÿ¨ÿŒÿ	‚ÿtÿgÿ\ÿR	ÿJÿDÿ=ÿ5ÿ/ÿ	Tÿuÿ+ÿÿÿÿÿ+ÿÿÿÿÿÿ
ÿ
ÿ
ÿÿÿÿÿ1ÿ&Iÿ+Rÿ8ÿÿÿÿÿ ÿ#ÿ5ÿ+ÿÿÿÿ 
ÿÿÿSÿªÿ	†ÿhÿ	lÿ	nÿ	oÿ	tÿ	|ÿƒÿ„ÿ„ÿ
~ÿ	tÿiÿ`ÿUÿ:	ÿ ÿÿ+ÿ8ÿ4ÿ/ÿ)ÿHÿ}ÿsÿ,ÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿ=ÿ(‘Lÿt;ÿÿÿÿÿÿÿÿ"ÿ&ÿÿÿÿ  ÿ  ÿÿ9ÿˆ
ÿU	ÿJÿKÿTÿUÿWÿLÿ:ÿ5ÿ1ÿ1ÿ@ÿK
ÿEÿ'ÿÿÿ5ÿ
ÿ+ÿ(ÿ#ÿ"ÿcÿqÿ
Wÿÿÿÿÿÿÿÿÿÿ
ÿ	ÿaÿ	Uÿÿÿÿÿ
ÿÿ+ÿÿÿÿÿÿÿÿÿÿÿÿ  ÿ  ÿ  ÿÿÿ2ÿ/ÿÿÿÿ+ÿ>ÿ2ÿÿÿÿÿÿÿ3ÿ1ÿÿÿs=ÿ#€Dÿ
)ÿ$ÿ"ÿÿÿ	Sÿ`ÿ%ÿÿÿÿÿÿÿÿÿ
ÿÿÿÿÿÿÿÿÿ	ÿ
ÿ
ÿÿÿÿÿÿÿÿÿÿÿÿÿ  ÿÿÿ+ÿ-ÿÿÿ
ÿÿÿ1ÿÿÿÿÿÿÿÿ%ÿÿ	ÿÿ'Jÿj8ÿ!ÿÿÿÿÿÿÿÿÿÿÿÿÿÿ
ÿÿÿÿÿÿÿÿÿÿ%)%ÿÿÿÿÿÿÿÿÿÿ ÿ#ÿ$ÿÿÿÿÿ	ÿ&ÿ1ÿ5ÿÿÿ	ÿ
ÿ&ÿ1ÿÿÿÿ
ÿ
ÿÿ	ÿ
!
ÿ

ÿ
ÿ	ÿb3ÿ(ÿÿ

ÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿ