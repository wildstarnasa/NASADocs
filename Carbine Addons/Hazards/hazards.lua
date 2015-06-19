require "Window"
require "HazardsLib"

local Hazards = {}

local karBarSprites =
{
	["default"]						= 		{strIcon = "IconSprites:Icon_Windows32_UI_Hazards_Generic", 		strFillColor = "SprintMeter:sprHazards_Fill", 	strEdgeColor = "SprintMeter:sprHazards_EdgeGlow"},
	[HazardsLib.HazardType_Radiation] = 	{strIcon = "IconSprites:Icon_Windows32_UI_Hazards_Radiation", 		strFillColor = "SprintMeter:sprHazards_Fill", 	strEdgeColor = "SprintMeter:sprHazards_EdgeGlow"},
	[HazardsLib.HazardType_Temperature] = 	{strIcon = "IconSprites:Icon_Windows32_UI_Hazards_Temperature", 	strFillColor = "SprintMeter:sprHazards_Fill", 	strEdgeColor = "SprintMeter:sprHazards_EdgeGlow"},
	[HazardsLib.HazardType_Proximity] = 	{strIcon = "IconSprites:Icon_Windows32_UI_Hazards_Proximity", 		strFillColor = "SprintMeter:sprHazards_Fill", 	strEdgeColor = "SprintMeter:sprHazards_EdgeGlow"},
	[HazardsLib.HazardType_Timer] = 		{strIcon = "IconSprites:Icon_Windows32_UI_Hazards_Proximity", 		strFillColor = "SprintMeter:sprHazards_Fill", 	strEdgeColor = "SprintMeter:sprHazards_EdgeGlow"},
	[HazardsLib.HazardType_Breath] = 		{strIcon = "IconSprites:Icon_Windows32_UI_Hazards_Water", 			strFillColor = "SprintMeter:sprHazards_Fill", 	strEdgeColor = "SprintMeter:sprHazards_EdgeGlow"},
}

local knBreathFakeId = -1

function Hazards:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	o.tWndRefs = {}
	o.tHazardWnds = {}
	
	return o
end

function Hazards:Init()
	Apollo.RegisterAddon(self)
end

function Hazards:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Hazards.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Hazards:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("BreathChanged", "OnBreathChanged", self)
	Apollo.RegisterEventHandler("Breath_FlashEvent", "OnBreath_FlashEvent", self) -- Drowning
	Apollo.RegisterEventHandler("HazardEnabled", "OnHazardEnable", self)
	Apollo.RegisterEventHandler("HazardRemoved", "OnHazardRemove", self)
	Apollo.RegisterEventHandler("HazardUpdated", "OnHazardsUpdated", self)
	Apollo.RegisterEventHandler("ChangeWorld", "ClearInterface", self)

	self.fTargetBreathLevel = 0
	self.fAdditionPerFrame = 0
	self.fCurrentBreathLevel = 100
	self.fBreathMax = 100
	self.bBreathShown = false
	
	self:OnHazardsUpdated()
end

function Hazards:BuildInterface()
	if self.tWndRefs.wndMain == nil or not self.tWndRefs.wndMain:IsValid() then
		local wndMain = Apollo.LoadForm(self.xmlDoc, "HazardListForm", "FixedHudStratum", self)
		self.tWndRefs.wndMain = wndMain
		self.tWndRefs.wndHazardList = wndMain:FindChild("HazardList")
		wndMain:Show(true)
	end
end

function Hazards:ClearInterface()
	if self.tWndRefs.wndMain ~= nil then
		self.tWndRefs.wndMain:Destroy()
	end
	self.tWndRefs = {}
	self.tHazardWnds = {}
end

function Hazards:OnHazardEnable(idHazard, strDisplayTxt)
	self:SetupHazardWindow(idHazard, strDisplayTxt)
	self:OnHazardsUpdated()
end

function Hazards:BuildHazardWindow(idHazard, eHazardType)
	self:BuildInterface()

	if self.tHazardWnds[idHazard] == nil then
		local wndHazard = Apollo.LoadForm(self.xmlDoc, "HazardProgressBar", self.tWndRefs.wndHazardList, self)
		wndHazard:SetData(eHazardType)
		self.tHazardWnds[idHazard] =
		{
			wndHazard = wndHazard,
			wndNumberText = wndHazard:FindChild("NumberText"),
			wndHazardProgress = wndHazard:FindChild("HazardProgress"),
			wndIcon = wndHazard:FindChild("Icon"),
			wndHazardsProgressFlash = wndHazard:FindChild("HazardsProgressFlash")
		}
	end

end

function Hazards:SetupHazardWindow(idHazard, strDisplayTxt)
	local eHazardType = nil
	for idx, tData in ipairs(HazardsLib.GetHazardActiveList()) do
		if tData.nId == idHazard then
			eHazardType = tData.eHazardType
		end
	end
	
	self:BuildHazardWindow(idHazard, eHazardType)

	local tSprites = karBarSprites[eHazardType] or karBarSprites["default"]

	self.tHazardWnds[idHazard].wndIcon:SetSprite(tSprites.strIcon)
	self.tHazardWnds[idHazard].wndHazardProgress:SetFillSprite(tSprites.strFillColor)
	self.tHazardWnds[idHazard].wndHazardProgress:SetGlowSprite(tSprites.strEdgeColor)
	self.tHazardWnds[idHazard].wndIcon:SetTooltip(strDisplayTxt)
end

function Hazards:OnHazardRemove(idHazard)
	if not self.tHazardWnds[idHazard] then
		return
	end

	self.tHazardWnds[idHazard].wndHazard:Destroy()
	self.tHazardWnds[idHazard] = nil

	if #self.tWndRefs.wndHazardList:GetChildren() == 0 then
		self:ClearInterface()
	else
		local nWidth = self.tWndRefs.wndHazardList:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
		local nLeft, nTop, nRight, nBottom = self.tWndRefs.wndMain:GetAnchorOffsets()
		self.tWndRefs.wndMain:SetAnchorOffsets(nRight - nWidth, nTop, nRight, nBottom)
	end
end

function Hazards:OnHazardsUpdated()
	local bNew = false
	for idx, tData in ipairs(HazardsLib.GetHazardActiveList()) do
		if not self.tHazardWnds[tData.nId] then
			self:SetupHazardWindow(tData.nId, HazardsLib.GetHazardDisplayString(tData.nId))
			bNew = true
		end
		
		self:OnHazardUpdate(tData.nId, tData.eHazardType, tData.fMeterValue, tData.fMaxValue, tData.strTooltip)
	end

	if bNew and self.tWndRefs.wndMain ~= nil and self.tWndRefs.wndMain:IsValid() then
		local nWidth = self.tWndRefs.wndHazardList:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
		local nLeft, nTop, nRight, nBottom = self.tWndRefs.wndMain:GetAnchorOffsets()
		self.tWndRefs.wndMain:SetAnchorOffsets(nRight - nWidth, nTop, nRight, nBottom)
	end
end

function Hazards:OnHazardUpdate(idHazard, eHazardType, fMeterValue, fMaxValue, strTooltip)
	if self.tHazardWnds[idHazard] then
		-- find the progress bar and update the limits
		local wndProgressBar = self.tHazardWnds[idHazard].wndHazardProgress
		wndProgressBar:SetMax(fMaxValue)

		if fMaxValue == fMeterValue then
			wndProgressBar:SetProgress(fMaxValue - .001, fMaxValue)
		else
			wndProgressBar:SetProgress(fMeterValue, fMaxValue)
		end

		--Cut down to integers only; we assume this is out of 100

		if eHazardType ~= HazardsLib.HazardType_Timer then -- standard percent
			local strPercent = (fMeterValue / fMaxValue) * 100
			self.tHazardWnds[idHazard].wndNumberText:SetText(string.format("%.0f", strPercent))
		else
			local strTime = string.format("%d:%02d", math.floor(fMeterValue / 60), math.floor(fMeterValue % 60))
			self.tHazardWnds[idHazard].wndNumberText:SetText(strTime)
		end

		if strTooltip ~= nil then
			wndProgressBar:SetTooltip(strTooltip)
		end
	end
end

function Hazards:OnBreathChanged(nBreath)
	local idHazard = knBreathFakeId
	local eHazardType = HazardsLib.HazardType_Breath
	local nBreathMax = 100
	
	if nBreath == nBreathMax then
		self:OnHazardRemove(idHazard)
		return
	end
	
	if self.tHazardWnds[idHazard] == nil then
		self:BuildHazardWindow(idHazard, eHazardType)
	
		local tSprites = karBarSprites[eHazardType] or karBarSprites["default"]
	
		self.tHazardWnds[idHazard].wndIcon:SetSprite(tSprites.strIcon)
		self.tHazardWnds[idHazard].wndHazardProgress:SetFillSprite(tSprites.strFillColor)
		self.tHazardWnds[idHazard].wndHazardProgress:SetGlowSprite(tSprites.strEdgeColor)
		self.tHazardWnds[idHazard].wndIcon:SetTooltip(Apollo.GetString("CRB_Breath_"))
		
		local nWidth = self.tWndRefs.wndHazardList:ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.LeftOrTop)
		local nLeft, nTop, nRight, nBottom = self.tWndRefs.wndMain:GetAnchorOffsets()
		self.tWndRefs.wndMain:SetAnchorOffsets(nRight - nWidth, nTop, nRight, nBottom)
	end
	
	self:OnHazardUpdate(idHazard, eHazardType, nBreath, nBreathMax, nil)
end

function Hazards:OnBreath_FlashEvent()
	if self.tHazardWnds[knBreathFakeId] ~= nil then
		self.tHazardWnds[knBreathFakeId].wndHazardsProgressFlash:SetSprite("SprintMeter:sprHazards_Flash")
	end
end


local HazardInst = Hazards:new()
HazardInst:Init()