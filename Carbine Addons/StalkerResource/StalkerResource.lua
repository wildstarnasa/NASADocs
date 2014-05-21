-----------------------------------------------------------------------------------------------
-- Client Lua Script for StalkerResource
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"
require "Unit"

local StalkerResource = {}

function StalkerResource:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function StalkerResource:Init()
	Apollo.RegisterAddon(self, nil, nil, {"ActionBarFrame"})
end

function StalkerResource:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("StalkerResource.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function StalkerResource:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("ActionBarLoaded", "OnRequiredFlagsChanged", self)
	self:OnRequiredFlagsChanged()
end

function StalkerResource:OnRequiredFlagsChanged()
	if g_wndActionBarResources then
		if GameLib.GetPlayerUnit() then
			self:OnCharacterCreated()
		else
			Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
		end
	end
end

function StalkerResource:OnCharacterCreated()
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer:GetClassId() ~= GameLib.CodeEnumClass.Stalker then
		return
	end

	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)

	self.wndResourceBar = Apollo.LoadForm(self.xmlDoc, "StalkerResourceForm", g_wndActionBarResources, self)
	self.wndResourceBar:ToFront()
	
	self.xmlDoc = nil
end

function StalkerResource:OnFrame(varName, cnt)
	if not self.wndResourceBar:IsValid() then
		return
	end
	
	local nLeft, nTop, nRight, nBottom = self.wndResourceBar:GetRect()
	Apollo.SetGlobalAnchor("CastingBarBottom", 0.0, nTop - 10, true)

	----------Resource 3
	local unitPlayer = GameLib.GetPlayerUnit()
	local nResourceCurrent = unitPlayer:GetResource(3)
	local nResourceMax = unitPlayer:GetMaxResource(3)
	local bInCombat = unitPlayer:IsInCombat()
	
	self.wndResourceBar:FindChild("CenterMeter1"):SetStyleEx("EdgeGlow", nResourceCurrent < nResourceMax)
	self.wndResourceBar:FindChild("CenterMeter1"):SetMax(nResourceMax)
	self.wndResourceBar:FindChild("CenterMeter1"):SetProgress(nResourceCurrent)
	self.wndResourceBar:FindChild("CenterMeter2"):SetStyleEx("EdgeGlow", nResourceCurrent < nResourceMax)
	self.wndResourceBar:FindChild("CenterMeter2"):SetMax(nResourceMax)
	self.wndResourceBar:FindChild("CenterMeter2"):SetProgress(nResourceCurrent)
	self.wndResourceBar:FindChild("CenterMeterText"):SetText(nResourceCurrent)
	self.wndResourceBar:FindChild("CenterMeterText"):Show(bInCombat or nResourceCurrent ~= nResourceMax)
	
	local wndBase = self.wndResourceBar:FindChild("Base")
	local wndInnate = self.wndResourceBar:FindChild("Innate")
	local strBaseWindow = ""
	local strInnateWindow = ""	
	
	if bInCombat then
		if nResourceCurrent == nResourceMax then
			strBaseWindow = "Full"
		else
			strBaseWindow = "Innate"
		end
	else
		strBaseWindow = "OutOfCombat"
	end
	
	if GameLib.IsCurrentInnateAbilityActive() then
		strInnateWindow = bInCombat and "InCombat" or "OutOfCombat"
	end
	
	if wndInnate:GetData() ~= strInnateWindow then
		wndInnate:FindChild("InCombat"):Show(false)
		wndInnate:FindChild("OutOfCombat"):Show(false)
		
		if strInnateWindow ~= "" then
			wndInnate:FindChild(strInnateWindow):Show(true)
		end
		
		wndInnate:SetData(bInnateWindow)
	end
	
	self.wndResourceBar:FindChild("Dot1"):Show(not bInCombat and nResourceCurrent == nResourceMax)
	self.wndResourceBar:FindChild("Dot2"):Show(not bInCombat and nResourceCurrent == nResourceMax)
	self.wndResourceBar:FindChild("Dot3"):Show(bInCombat and nResourceCurrent == nResourceMax)
	--self.wndResourceBar:FindChild("Dot4"):Show(bInCombat and nResourceCurrent == nResourceMax)
	
	if wndBase:GetData() ~= strBaseWindow then
		self.wndResourceBar:FindChild("CenterMeterText"):SetTextColor(bInCombat and ApolloColor.new("xkcdLightblue") or ApolloColor.new("UI_TextHoloTitle"))
		self.wndResourceBar:FindChild("CenterMeter1"):Show(not bInCombat)
		self.wndResourceBar:FindChild("CenterMeter2"):Show(bInCombat)
		
		wndBase:FindChild("Full"):Show(false)
		wndBase:FindChild("Innate"):Show(false)
		wndBase:FindChild("InCombat"):Show(false)
		wndBase:FindChild("OutOfCombat"):Show(false)
		
		wndBase:FindChild(strBaseWindow):Show(true, false, 0.3)
	
		wndBase:SetData(strBaseWindow)
	end
	
	--Toggle Visibility based on ui preference
	local unitPlayer = GameLib.GetPlayerUnit()
	local nVisibility = Apollo.GetConsoleVariable("hud.ResourceBarDisplay")
	
	if nVisibility == 2 then --always off
		self.wndResourceBar:Show(false)
	elseif nVisibility == 3 then --on in combat
		self.wndResourceBar:Show(bInCombat)	
	elseif nVisibility == 4 then --on out of combat
		self.wndResourceBar:Show(not bInCombat)
	else
		self.wndResourceBar:Show(true)
	end
end

local StalkerResourceInst = StalkerResource:new()
StalkerResourceInst:Init()
