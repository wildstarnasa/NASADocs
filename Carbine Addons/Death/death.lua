-----------------------------------------------------------------------------------------------
-- Client Lua Script for Death
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Window"
require "Tooltip"
require "XmlDoc"
require "GameLib"
require "MatchingGame"

---------------------------------------------------------------------------------------------------
-- Death module definition
---------------------------------------------------------------------------------------------------
local Death = {}

---------------------------------------------------------------------------------------------------
-- local constants
---------------------------------------------------------------------------------------------------
local RezType =
{
	Here = 1,
	Eldan = 2,
	SpellCasterLocation = 4,
	ExitInstance = 32
}

local kcrCanResurrectButtonColor = CColor.new(1, 1, 1, 1)
local kcrCannotResurrectButtonColor = CColor.new(.6, .6, .6, 1)
local kcrCanResurrectTextColor = ApolloColor.new("ff9aaea3")
local kcrCannotResurrectTextColor = CColor.new(.3, .3, .3, 1)

local knSaveVersion = 2

---------------------------------------------------------------------------------------------------
-- Death functions
---------------------------------------------------------------------------------------------------
function Death:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.wndResurrect = nil
	o.nGoldPenalty = 0
	o.bEnableRezHere = true
	o.bEnableCasterRez = false
	o.bHasCasterRezRequest = false
	o.nRezCost = 0
	o.fTimeBeforeRezable = 0
	o.fTimeBeforeWakeHere = 0

	return o
end

function Death:Init()
	Apollo.RegisterAddon(self)
end

---------------------------------------------------------------------------------------------------
-- EventHandlers
---------------------------------------------------------------------------------------------------
function Death:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Death.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end


function Death:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		
		Apollo.RegisterEventHandler("ShowResurrectDialog", 		"OnShowResurrectDialog", self)
		Apollo.RegisterEventHandler("UpdateResurrectDialog", 	"OnUpdateResurrectDialog", self)
		Apollo.RegisterEventHandler("ShowIncapacitationBar", 	"ShowIncapacitationBar", self)
		Apollo.RegisterEventHandler("HideIncapacitationBar", 	"HideIncapacitationBar", self)
		Apollo.RegisterEventHandler("CasterResurrectedPlayer", 	"CasterResurrectedPlayer", self)
		Apollo.RegisterEventHandler("ForceResurrect", 			"OnForcedResurrection", self)
		Apollo.RegisterEventHandler("ScriptResurrect", 			"OnScriptResurrection", self)
		Apollo.RegisterEventHandler("MatchExited", 				"OnForcedResurrection", self)
		Apollo.RegisterEventHandler("PVPDeathmatchPoolUpdated", "OnPVPDeathmatchPoolUpdated", self)
		Apollo.RegisterEventHandler("CharacterCreated", 		"OnCharacterCreated", self)

		self.wndResurrect = Apollo.LoadForm(self.xmlDoc, "ResurrectDialog", nil, self)
		self.wndResurrect:Show(false)

		self.wndExitConfirm = Apollo.LoadForm(self.xmlDoc, "ExitInstanceDialog", nil, self)
		self.wndExitConfirm:Show(false)	
		
		if self.locSavedWindowLoc then
			self.wndResurrect:MoveToLocation(self.locSavedWindowLoc)
		end
		
		self.xmlDoc = nil
		
		self.nTimerProgress = nil
		self.bDead = false
		
		self.timerTenthSec = ApolloTimer.Create(0.10, true, "OnTenthSecTimer", self)
		self.timerTenthSec:Stop()

		if GameLib.GetPlayerUnit() then
			self:OnCharacterCreated()
		end
	end
end

function Death:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end
	
	local tSaveData = 
	{
		bCasterRezzed = self.bHasCasterRezRequest,
		tWindowLocation = self.wndResurrect and self.wndResurrect:GetLocation():ToTable() or self.locSavedWindowLoc:ToTable(),
		nSaveVersion = knSaveVersion,
	}
	return tSaveData
end

function Death:OnRestore(eType, tSavedData)
	self.tSavedData = tSavedData
	if tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.bHasCasterRezRequest = tSavedData.bCasterRezzed
		self.locSavedWindowLoc = WindowLocation.new(tSavedData.tWindowLocation)
	end
end

---------------------------------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------------------------------
function Death:OnCharacterCreated()
	local unitPlayer = GameLib.GetPlayerUnit()
	
	if unitPlayer:IsDead() == false then
		return
	end
	
	self.bDead = true
	self.fTimeBeforeRezable = GetDeathPenalty() 
	self.fTimeBeforeWakeHere = GetWakeHereTime() 
	self.fTimeBeforeForceRez = GetForceRezTime() 
	self.nRezCost = GetRezCost() 
	self.bEnableRezHere = GetRezOptionWakeHere() 
	self.bEnableRezHoloCrypt = GetRezOptionHolocrypt() 
	self.bEnableRezExitInstance = GetRezOptionExitInstance()
	self.bEnableCasterRez = GetRezOptionAcceptCasterRez()
	
	self:OnShowResurrectDialog(self.bDead, self.bEnableRezHere, self.bEnableRezHoloCrypt, self.bEnableRezExitInstance, self.bEnableCasterRez, self.bHasCasterRezRequest, self.nRezCost, self.fTimeBeforeRezable, self.fTimeBeforeWakeHere, self.fTimeBeforeForceRez)
end

function Death:OnShowResurrectDialog(bPlayerIsDead, bEnableRezHere, bEnableRezHoloCrypt, bEnableRezExitInstance, bEnableCasterRez, bHasCasterRezRequest, nRezCost, fTimeBeforeRezable, fTimeBeforeWakeHere, fTimeBeforeForceRez)
	self.timerTenthSec:Start()
	
	self.bDead = bPlayerIsDead
	
	self:OnUpdateResurrectDialog(bEnableRezHere, bEnableRezHoloCrypt, bEnableRezExitInstance, bEnableCasterRez, bHasCasterRezRequest, nRezCost, fTimeBeforeRezable, fTimeBeforeWakeHere, fTimeBeforeForceRez)
end

function Death:OnUpdateResurrectDialog(bEnableRezHere, bEnableRezHoloCrypt, bEnableRezExitInstance, bEnableCasterRez, bHasCasterRezRequest, nRezCost, fTimeBeforeRezable, fTimeBeforeWakeHere, fTimeBeforeForceRez)
	self.bEnableRezHere = bEnableRezHere
	self.bEnableRezHoloCrypt = bEnableRezHoloCrypt
	self.bEnableRezExitInstance = bEnableRezExitInstance
	self.bEnableCasterRez = bEnableCasterRez or false
	self.bHasCasterRezRequest = bHasCasterRezRequest
	self.nRezCost = nRezCost
	self.fTimeBeforeRezable = fTimeBeforeRezable
	self.fTimeBeforeWakeHere = fTimeBeforeWakeHere
	self.fTimeBeforeForceRez = fTimeBeforeForceRez
	
	if self.bDead == false then
		self.wndExitConfirm:Show(false)	
		self.wndResurrect:Show(false)
		self.nTimerProgress = nil
		return
	end
	
	--hide and format everything
	self.wndExitConfirm:Show(false)	
	self.wndResurrect:FindChild("ResurrectDialog.Caster"):Show(false)
	self.wndResurrect:FindChild("ResurrectDialog.Here"):Show(false)
	self.wndResurrect:FindChild("ResurrectDialog.Eldan"):Show(false)
	self.wndResurrect:FindChild("ResurrectDialog.ExitInstance"):Show(false)
	self.wndResurrect:FindChild("ResurrectDialog.EldanSmall"):Show(false)
	self.wndResurrect:FindChild("ResurrectDialog.ExitInstanceSmall"):Show(false)	
	self.wndResurrect:FindChild("ArtTimeToRezHere"):SetText(Apollo.GetString("CRB_Time_Remaining_2"))
	self.wndResurrect:FindChild("ArtTimeToRezHere"):Show(true)
	self.wndResurrect:FindChild("ForceRezText"):Show(false)
	
	if self.bDead and not self.wndResurrect:IsShown() then
		self.wndResurrect:Invoke()
	end
end


------------------------------------//------------------------------
function Death:OnTenthSecTimer() -- there's no reason we can't run the whole thing off of this
	if self.bDead ~= true or not self.wndResurrect:IsVisible() then
		self.bHasCasterRezRequest = false
		return
	end
	
	local nLeft, nTop, nRight, nBottom = self.wndResurrect:GetAnchorOffsets()
			
	-- update all of our timers
	self.fTimeBeforeWakeHere = self.fTimeBeforeWakeHere - 100
	self.fTimeBeforeForceRez = self.fTimeBeforeForceRez - 100
	self.fTimeBeforeRezable = self.fTimeBeforeRezable - 100
			
	if self.fTimeBeforeRezable > 0 then -- this timer takes precendence over everything. if it has a count, the player can't do anything
		local strTimeBeforeRezableFormatted = self:HelperCalcTimeSecondsMS(self.fTimeBeforeRezable)
		self.wndResurrect:FindChild("ResurrectDialog.Timer"):SetText(strTimeBeforeRezableFormatted .. Apollo.GetString("CRB__seconds"))
		self.wndResurrect:FindChild("ResurrectDialog.Timer"):Show(true)
		self.wndResurrect:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 211)
	else
		local tMatchInfo = MatchingGame.GetPVPMatchState()
		if tMatchInfo ~= nil then
			if tMatchInfo.eRules == MatchingGame.Rules.DeathmatchPool then
				if (tMatchInfo.eMyTeam == MatchingGame.Team.Team1 and tMatchInfo.tLivesRemaining.nTeam1 == 0) or (tMatchInfo.eMyTeam == MatchingGame.Team.Team2 and tMatchInfo.tLivesRemaining.nTeam2 == 0) then
					self.wndResurrect:FindChild("ResurrectDialog.Timer"):SetText(Apollo.GetString("Death_NoLives"))
					self.wndResurrect:FindChild("ResurrectDialog.Timer"):Show(true)	
					self.wndResurrect:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 211)
					self.wndResurrect:FindChild("ForceRezText"):Show(false)
					self.wndResurrect:FindChild("ResurrectDialog.Here"):Show(false)
					self.wndResurrect:FindChild("ResurrectDialog.Eldan"):Show(false)
					self.wndResurrect:FindChild("ResurrectDialog.EldanSmall"):Show(false)
					self.wndResurrect:FindChild("ResurrectDialog.ExitInstanceSmall"):Show(false)		
					self.wndResurrect:FindChild("ResurrectDialog.Caster"):Show(false)	
					return
				end
			elseif tMatchInfo.eRules == MatchingGame.Rules.WaveRespawn then
				self.wndResurrect:Close()
				return
			end
		end
	
		self.wndResurrect:FindChild("ArtTimeToRezHere"):Show(false)
		self.wndResurrect:FindChild("ResurrectDialog.Timer"):Show(false)
		self.wndResurrect:FindChild("ForceRezText"):Show(self.fTimeBeforeForceRez > 0)
		self.wndResurrect:FindChild("ResurrectDialog.Here"):Show(self.bEnableRezHere)
		self.wndResurrect:FindChild("ResurrectDialog.Eldan"):Show(self.bEnableRezHoloCrypt and not self.bEnableRezExitInstance)
		self.wndResurrect:FindChild("ResurrectDialog.ExitInstance"):Show(not self.bEnableRezHoloCrypt and self.bEnableRezExitInstance)
		self.wndResurrect:FindChild("ResurrectDialog.EldanSmall"):Show(self.bEnableRezHoloCrypt and self.bEnableRezExitInstance)
		self.wndResurrect:FindChild("ResurrectDialog.ExitInstanceSmall"):Show(self.bEnableRezHoloCrypt and self.bEnableRezExitInstance)		
		self.wndResurrect:FindChild("ResurrectDialog.Caster"):Show(self.bEnableCasterRez and self.bHasCasterRezRequest)	
		

		if self.wndResurrect:FindChild("ResurrectDialog.Caster"):IsShown() then
			self.wndResurrect:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 320)
		elseif self.wndResurrect:FindChild("ResurrectDialog.Here"):IsShown() or self.wndResurrect:FindChild("ResurrectDialog.EldanSmall"):IsShown() then
			self.wndResurrect:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 288)
		else
			self.wndResurrect:SetAnchorOffsets(nLeft, nTop, nRight, nTop + 220)
		end
		
		self.wndResurrect:FindChild("ResurrectDialogButtons"):ArrangeChildrenVert(0)
		-- set up rez here
		if self.wndResurrect:FindChild("ResurrectDialog.Here"):IsShown() then
			local wndBtn = self.wndResurrect:FindChild("ResurrectDialog.Here")
			wndBtn:FindChild("ResurrectDialog.Cash"):SetAmount(self.nRezCost)
						
			if self.fTimeBeforeWakeHere <= 0 then  -- ready to go
				local bCanAfford = self.nRezCost <= GameLib.GetPlayerCurrency():GetAmount()
				wndBtn:Enable(bCanAfford)
				wndBtn:FindChild("WakeHereText"):SetText(Apollo.GetString("Death_WakeHere"))
				wndBtn:FindChild("WakeHereCooldownText"):SetText("")
				wndBtn:FindChild("ResurrectDialog.Cash"):Show(true)
				wndBtn:FindChild("CostLabel"):Show(true)
				if bCanAfford then
					self.wndResurrect:FindChild("ResurrectDialog.Here"):SetBGColor(kcrCanResurrectButtonColor)
					wndBtn:FindChild("WakeHereText"):SetTextColor(kcrCanResurrectTextColor)
					wndBtn:FindChild("ResurrectDialog.Cash"):SetTextColor(ApolloColor.new("white"))
				else -- not enough money
					self.wndResurrect:FindChild("ResurrectDialog.Here"):SetBGColor(kcrCannotResurrectButtonColor)
					wndBtn:FindChild("WakeHereText"):SetTextColor(kcrCannotResurrectTextColor)	
					wndBtn:FindChild("ResurrectDialog.Cash"):SetTextColor(ApolloColor.new("red"))						
				end	
			else -- still cooling down
				wndBtn:Enable(false)
				local strCooldownFormatted = self:HelperCalcTimeMS(self.fTimeBeforeWakeHere)
				wndBtn:FindChild("WakeHereCooldownText"):SetText(String_GetWeaselString(Apollo.GetString("Death_CooldownTimer"), strCooldownFormatted))
				wndBtn:FindChild("ResurrectDialog.Cash"):Show(false)
				wndBtn:FindChild("CostLabel"):Show(false)
				self.wndResurrect:FindChild("ResurrectDialog.Here"):SetBGColor(kcrCannotResurrectButtonColor)
				wndBtn:FindChild("WakeHereText"):SetTextColor(kcrCannotResurrectTextColor)					
			end
		end	
	end
		
	if self.fTimeBeforeForceRez > 0 then
		local strTimeFormatted = self:HelperCalcTimeMS(self.fTimeBeforeForceRez)
		self.wndResurrect:FindChild("ForceRezText"):SetText(String_GetWeaselString(Apollo.GetString("Death_AutoRelease"), strTimeFormatted))
	end

end

------------------------------------//------------------------------

function Death:CasterResurrectedPlayer(strCasterName)
	self.bHasCasterRezRequest = true;
end

function Death:OnResurrectHere()
	if GameLib.GetPlayerUnit() ~= nil then
		GameLib.GetPlayerUnit():Resurrect(RezType.Here, 0)
	end
	
	self.wndResurrect:Close()
	self.bDead = false
	
	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
end
------------------------------------//------------------------------
function Death:OnResurrectCaster()
	if GameLib.GetPlayerUnit() ~= nil then
		GameLib.GetPlayerUnit():Resurrect(RezType.SpellCasterLocation, 0) -- WIP, this should send in the UnitId of the caster
	end
	
	self.wndResurrect:Close()
	self.bDead = false
	
	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
end
------------------------------------//------------------------------
function Death:OnResurrectEldan()
	if GameLib.GetPlayerUnit() ~= nil then
		GameLib.GetPlayerUnit():Resurrect(RezType.Eldan, 0)
	end

	self.wndResurrect:Show(false)
	self.bDead = false
	
	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
	
	if GameLib.GetPvpFlagInfo().nCooldown then
		ChatSystemLib.PostOnChannel( ChatSystemLib.ChatChannel_System, Apollo.GetString("Death_PvPFlagReset"), "" )
	end
end
------------------------------------//------------------------------
function Death:OnExitInstance()
	self.wndExitConfirm:Invoke()
	self.wndResurrect:Close()
end

function Death:OnConfirmExit()
	if GameLib.GetPlayerUnit() ~= nil then
		GameLib.GetPlayerUnit():Resurrect(RezType.ExitInstance, 0)
	end

	self.wndExitConfirm:Close()	
	self.wndResurrect:Close()
	self.bDead = false
	
	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
end

function Death:OnCancelExit()
	self.wndExitConfirm:Close()	
	self.wndResurrect:Invoke()
end

------------------------------------//------------------------------
function Death:OnForcedResurrection()
	self.wndExitConfirm:Show(false)	
	self.wndResurrect:Close()
	self.bDead = false

	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
end

------------------------------------//------------------------------
function Death:OnScriptResurrection()
	self.wndExitConfirm:Show(false)	
	self.wndResurrect:Close()
	self.bDead = false

	self.timerTenthSec:Stop()
	Event_FireGenericEvent("PlayerResurrected")
end

------------------------------------//------------------------------

function Death:HideIncapacitationBar()
	self.wndExitConfirm:Show(false)	
	self.wndResurrect:Show(false)
end

function Death:HelperCalcTimeSecondsMS(fTimeMS)
	local fTime = math.floor(fTimeMS / 1000)
	local fMillis = fTimeMS % 1000
	return string.format("%d.%d", fTime, math.floor(fMillis / 100))
end

function Death:HelperCalcTimeMS(fTimeMS)
	local fSeconds = fTimeMS / 1000
	local fMillis = fTimeMS % 1000
	local strOutputSeconds = "00"
	if math.floor(fSeconds % 60) >= 10 then
		strOutputSeconds = tostring(math.floor(fSeconds % 60))
	else
		strOutputSeconds = "0" .. math.floor(fSeconds % 60)
	end
	
	return String_GetWeaselString(Apollo.GetString("CRB_TimeMinsToMS"), math.floor(fSeconds / 60), strOutputSeconds, math.floor(fMillis / 100))
end

function Death:HelperCalcTime(fSeconds)
	local strOutputSeconds = "00"
	if math.floor(fSeconds % 60) >= 10 then
		strOutputSeconds = tostring(math.floor(fSeconds % 60))
	else
		strOutputSeconds = "0" .. math.floor(fSeconds % 60)
	end
	
	return String_GetWeaselString(Apollo.GetString("CRB_TimeMinsToMS"), math.floor(fSeconds / 60), strOutputSeconds)
end

---------------------------------------------------------------------------------------------------
-- Death instance
---------------------------------------------------------------------------------------------------
local DeathInst = Death:new()
DeathInst:Init()
