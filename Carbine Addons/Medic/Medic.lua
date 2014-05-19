-----------------------------------------------------------------------------------------------
-- Client Lua Script for Medic
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Unit"
require "Spell"

local Medic = {}

function Medic:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Medic:Init()
    Apollo.RegisterAddon(self, nil, nil, {"ActionBarFrame"})
end

function Medic:OnLoad()
	--[[ DEPRECATED: Replaced by \ClassResources\
	self.xmlDoc = XmlDoc.CreateFromFile("Medic.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)

	Apollo.RegisterEventHandler("ActionBarLoaded", "OnRequiredFlagsChanged", self)
	]]--
end

function Medic:OnDocumentReady()
	self.bDocLoaded = true
	self:OnRequiredFlagsChanged()
end

function Medic:OnRequiredFlagsChanged()
	if g_wndActionBarResources and self.bDocLoaded then
		if GameLib.GetPlayerUnit() then
			self:OnCharacterCreated()
		else
			Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
		end
	end
end

function Medic:OnCharacterCreated()
	local unitPlayer = GameLib.GetPlayerUnit()

	if not unitPlayer then
		return
	elseif unitPlayer:GetClassId() ~= GameLib.CodeEnumClass.Medic then
		if self.wndMain then
			self.wndMain:Destroy()
		end
		return
	end

	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "MedicResourceForm", g_wndActionBarResources, self)
    self.wndMain:Show(false)

	local strResource = string.format("<T Font=\"CRB_InterfaceSmall\">%s</T>", Apollo.GetString("CRB_MedicResource"))
	self.wndMain:FindChild("ResourceContainer1"):SetTooltip(strResource)
	self.wndMain:FindChild("ResourceContainer2"):SetTooltip(strResource)
	self.wndMain:FindChild("ResourceContainer3"):SetTooltip(strResource)
	self.wndMain:FindChild("ResourceContainer4"):SetTooltip(strResource)

	self.tCores = {} -- windows

	for idx = 1,4 do
		self.tCores[idx] =
		{
			wndCore = Apollo.LoadForm(self.xmlDoc, "CoreForm",  self.wndMain:FindChild("ResourceContainer" .. idx), self),
			bFull = false
		}
	end

	self.xmlDoc = nil
end

function Medic:OnFrame()
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	elseif unitPlayer:GetClassId() ~= GameLib.CodeEnumClass.Medic then
		if self.wndMain then
			self.wndMain:Destroy()
		end
		return
	end

	if not self.wndMain:IsValid() then
		return
	end

	if not self.wndMain:IsVisible() then
		self.wndMain:Show(true)
	end

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetRect() -- legacy code
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop - 15, true)

	self:DrawCores(unitPlayer) -- right id, draw core info

	-- Resource 2 (Mana)
	local nManaMax = unitPlayer:GetMaxMana()
	local nManaCurrent = unitPlayer:GetMana()
	self.wndMain:FindChild("ManaProgressBar"):SetMax(nManaMax)
	self.wndMain:FindChild("ManaProgressBar"):SetProgress(nManaCurrent)
	if nManaCurrent == nManaMax then
		self.wndMain:FindChild("ManaProgressText"):SetText(nManaMax)
	else
		--self.wndMain:FindChild("ManaProgressText"):SetText(string.format("%.02f/%s", nManaCurrent, nManaMax))
		self.wndMain:FindChild("ManaProgressText"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), math.floor(nManaCurrent), nManaMax))
	end

	local strMana = String_GetWeaselString(Apollo.GetString("Medic_FocusTooltip"), nManaCurrent, nManaMax)
	self.wndMain:FindChild("ManaProgressBar"):SetTooltip(string.format("<T Font=\"CRB_InterfaceSmall\">%s</T>", strMana))

	--Toggle Visibility based on ui preference
	local unitPlayer = GameLib.GetPlayerUnit()
	local nVisibility = Apollo.GetConsoleVariable("hud.ResourceBarDisplay")

	if nVisibility == 2 then --always off
		self.wndMain:Show(false)
	elseif nVisibility == 3 then --on in combat
		self.wndMain:Show(unitPlayer:IsInCombat())
	elseif nVisibility == 4 then --on out of combat
		self.wndMain:Show(not unitPlayer:IsInCombat())
	else
		self.wndMain:Show(true)
	end
end

function Medic:DrawCores(unitPlayer)

	local nResourceCurr = unitPlayer:GetResource(1)
	local nResourceMax = unitPlayer:GetMaxResource(1)

	for idx = 1, #self.tCores do
		--self.tCores[idx].wndCore:Show(nResourceCurr ~= nil and nResourceMax ~= nil and nResourceMax ~= 0)
		local bFull = idx <= nResourceCurr
		self.tCores[idx].wndCore:FindChild("CoreFill"):Show(idx <= nResourceCurr)

		if bFull ~= self.tCores[idx].bFull then
			if bFull == false then -- burned a core
				self.tCores[idx].wndCore:FindChild("CoreFlash"):SetSprite("CRB_WarriorSprites:sprWar_FuelRedFlashQuick")
			else -- generated a core
				self.tCores[idx].wndCore:FindChild("CoreFlash"):SetSprite("CRB_WarriorSprites:sprWar_FuelRedFlash")
			end
		end

		self.tCores[idx].bFull = bFull
	end
end

-----------------------------------------------------------------------------------------------
-- Medic Instance
-----------------------------------------------------------------------------------------------
local MedicInst = Medic:new()
MedicInst:Init()
