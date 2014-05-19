-----------------------------------------------------------------------------------------------
-- Client Lua Script for DamageDisplay
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Unit"
require "GameLib"
require "Tooltip"

-----------------------------------------------------------------------------------------------
-- DamageDisplay Module Definition
-----------------------------------------------------------------------------------------------
local DamageDisplay = {}
local kHealDisplayDuration = 1.000
local kHealDelayDuration = 0.050
local kDamageDisplayDuration = 0.600
local kDamageDelayDuration = 0.050

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function DamageDisplay:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here

    return o
end

function DamageDisplay:Init()
    Apollo.RegisterAddon(self)
end


-----------------------------------------------------------------------------------------------
-- DamageDisplay OnLoad
-----------------------------------------------------------------------------------------------
function AbilityVendor:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("DamageDisplay.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function AbilityVendor:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
    Apollo.RegisterSlashCommand("dd", "OnDamageDisplayOn", self)
	Apollo.RegisterEventHandler("DamageOrHealingDone", "OnDamageOrHealing", self)
	Apollo.RegisterEventHandler("AttackMissed", "OnMiss", self )

    -- load our forms
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "DamageDisplayForm", nil, self)
	self.wndHeal = self.wndMain:FindChild("HealWindow")
	self.wndHeal:Show(false)
	self.wndDamage = self.wndMain:FindChild("DamageWindow")
	self.wndDamage:Show(false)
	self.xmlDoc = nil

	self.tHealQueue = {nFirst = 0, nLast = -1}
	self.tDamageQueue = {nFirst = 0, nLast = -1}
end


-----------------------------------------------------------------------------------------------
-- DamageDisplay Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/dd"
function DamageDisplay:OnDamageDisplayOn()
	if self.wndMain:IsVisible() then
		self.wndMain:Show(false)
	else
		self.wndMain:Show(true) -- show the window
	end
end

function DamageDisplay:OnDamageOrHealing( unitCaster, unitTarget, eDamageType, nDamage, nShieldDamage, nAbsorptionAmount, bCritical)
    if not GameLib.IsControlledUnit( unitTarget ) then return end -- if the target unit is player's char

	if eDamageType == GameLib.CodeEnumDamageType.Heal then
		self:AddToHealQueue(CColor.new(0.0, 1.0, 0.0, 0.6), nDamage, bCritical)
	elseif nShieldDamage and nShieldDamage ~= 0 then
		self:AddToDamageQueue(CColor.new(0.0, 0.45, 0.85, 0.7), string.format("-(%s)", nShieldDamage), bCritical)
	else
		local crText = CColor.new(1.0, 0.0, 0.0, 0.7)
		if eDamageType == GameLib.CodeEnumDamageType.Physical then
		   crText = CColor.new(1.0, 0.0, 0.0, 0.7)
		elseif eDamageType == GameLib.CodeEnumDamageType.Tech then
		   crText = CColor.new(1.0, 0.0, 0.0, 0.7)
		elseif eDamageType == GameLib.CodeEnumDamageType.Magic then
			crText = CColor.new(1.0, 0.0, 0.0, 0.7)
		end			
		self:AddToDamageQueue(crText, "- " .. nDamage, bCritical)		
	end
end

function DamageDisplay:OnMiss( unitCaster, unitTarget, eMissType )
    if unitTarget == nil then
        return
    end

    if not GameLib.IsControlledUnit(unitTarget) then -- if the target unit is not the player's char
		return
    end

	local strText = ""
    if eMissType == GameLib.CodeEnumMissType.Dodge then
        strText = Apollo.GetString("CRB_Dodged")
    else
        strText = Apollo.GetString("CRB_Blocked")
    end

	local crText = CColor.new(1.0, 0.0, 0.0, 1.0)
	local bCritical = true

	self:AddToDamageQueue(crText, strText, bCritical)
end

-----------------------------------------------------------------------------------------------
-- Health Queue Functions
-----------------------------------------------------------------------------------------------
function DamageDisplay:AddToHealQueue(crText, strText)
	local t = {color = crText, text = strText}
	local nLast = self.tHealQueue.nLast + 1
	self.tHealQueue.nLast = nLast
	self.tHealQueue[nLast] = t

	if self.wndHeal:IsVisible() == true then
		return
	else
		self:ProcessHeals()
	end
end

function DamageDisplay:ProcessHeals()
	self.wndHeal:SetText("")

	local nFirst = self.tHealQueue.nFirst
	if nFirst > self.tHealQueue.nLast then
		return
	end
	local t = self.tHealQueue[nFirst]
	self.tHealQueue[nFirst] = nil
	self.tHealQueue.nFirst = nFirst + 1

	self:DisplayHeal(t.color, t.text)
end

function DamageDisplay:DisplayHeal(HealColor, HealText)
	self.wndHeal:SetTextColor(HealColor)
	self.wndHeal:SetText("+ " .. HealText)
	self.wndHeal:Show(true)

	Apollo.CreateTimer("HealDisplayTimer", kHealDisplayDuration, false)
	if not self.bHealHandlerSet then
		Apollo.RegisterTimerHandler("HealDisplayTimer", "OnHealDisplayTimer", self)
		self.bHealHandlerSet = true
	end

end

---------------------------------------------------------------------------------------------------
function DamageDisplay:OnHealDisplayTimer()
	self.wndHeal:Show(false)
	Apollo.CreateTimer("HealDelayTimer", kHealDelayDuration, false)
	if not self.bHealDelayHandlerSet then
		Apollo.RegisterTimerHandler("HealDelayTimer", "OnHealDelayTimer", self)
		self.bHealDelayHandlerSet = true
	end
end

---------------------------------------------------------------------------------------------------
function DamageDisplay:OnHealDelayTimer()
	self.wndHeal:SetText("")
	self:ProcessHeals()
end



-----------------------------------------------------------------------------------------------
-- Damage Queue Functions
-----------------------------------------------------------------------------------------------
function DamageDisplay:AddToDamageQueue(crText, strText, bCritical)
	local t = {color = crText, text = strText, critical = bCritical}
	local nLast = self.tDamageQueue.nLast + 1
	self.tDamageQueue.nLast = nLast
	self.tDamageQueue[nLast] = t

	if self.wndDamage:IsVisible() == true then
		return
	else
		self:ProcessDamage()
	end
end

function DamageDisplay:ProcessDamage()
	self.wndDamage:FindChild("Normal"):SetText("")
	self.wndDamage:FindChild("Critical"):SetText("")

	local nFirst = self.tDamageQueue.nFirst
	if nFirst > self.tDamageQueue.nLast then
		return
	end
	local t = self.tDamageQueue[nFirst]
	self.tDamageQueue[nFirst] = nil
	self.tDamageQueue.nFirst = nFirst + 1

	self:DisplayDamage(t.color, t.text, t.critical)
end

function DamageDisplay:DisplayDamage(DamageColor, DamageText, bCritical)
	if bCritical == true then
		self.wndDamage:FindChild("Critical"):SetTextColor(DamageColor)
		self.wndDamage:FindChild("Critical"):SetText(DamageText .. "  ")
	else
		self.wndDamage:FindChild("Normal"):SetTextColor(DamageColor)
		self.wndDamage:FindChild("Normal"):SetText(DamageText)
	end

	self.wndDamage:Show(true)

	Apollo.CreateTimer("DamageDisplayTimer", kDamageDisplayDuration, false)
	if not self.bDamageHandlerSet then
		Apollo.RegisterTimerHandler("DamageDisplayTimer", "OnDamageDisplayTimer", self)
		self.bDamageHandlerSet = true
	end
end

---------------------------------------------------------------------------------------------------
function DamageDisplay:OnDamageDisplayTimer()
	Apollo.CreateTimer("DamageDelayTimer", kDamageDelayDuration, false)
	if not self.bDamageDelayHandlerSet then
		Apollo.RegisterTimerHandler("DamageDelayTimer", "OnDamageDelayTimer", self)
		self.bDamageDelayHandlerSet = true
	end
end

---------------------------------------------------------------------------------------------------
function DamageDisplay:OnDamageDelayTimer()
	self.wndDamage:Show(false)
	self.wndDamage:FindChild("Normal"):SetText("")
	self.wndDamage:FindChild("Critical"):SetText("")
	self:ProcessDamage()
end



-----------------------------------------------------------------------------------------------
-- DamageDisplay Instance
-----------------------------------------------------------------------------------------------
local DamageDisplayInst = DamageDisplay:new()
DamageDisplayInst:Init()
