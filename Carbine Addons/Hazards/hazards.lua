require "Window"
require "HazardsLib"

---------------------------------------------------------------------------------------------------

--Hazards
local Hazards = {}

local karBarSprites =  -- overall array; each table's formatting is icon, fill, edge
{
	["default"]						= 		{strIcon = "kitIcon_Gold_HazardGeneral", 		strFillColor = "kitIProgBar_HoloFrame_FillRed", 	strEdgeColor = "kitIProgBar_HoloFrame_CapRed"},
	[HazardsLib.HazardType_Radiation] = 	{strIcon = "kitIcon_Gold_HazardRadioactive", 	strFillColor = "kitIProgBar_HoloFrame_FillRed", 	strEdgeColor = "kitIProgBar_HoloFrame_CapRed"},
	[HazardsLib.HazardType_Temperature] = 	{strIcon = "kitIcon_Gold_HazardTemperature", 	strFillColor = "kitIProgBar_HoloFrame_FillBlue", 	strEdgeColor = "kitIProgBar_HoloFrame_CapRed"},
	[HazardsLib.HazardType_Proximity] = 	{strIcon = "kitIcon_Gold_HazardObserver", 		strFillColor = "kitIProgBar_HoloFrame_FillBlue", 	strEdgeColor = "kitIProgBar_HoloFrame_CapArrowR"},
	[HazardsLib.HazardType_Timer] = 		{strIcon = "kitIcon_Gold_HazardProximity", 		strFillColor = "kitIProgBar_HoloFrame_FillBlue", 	strEdgeColor = "kitIProgBar_HoloFrame_CapArrowL"},
}
---------------------------------------------------------------------------------------------------

function Hazards:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self

	return o
end

---------------------------------------------------------------------------------------------------

function Hazards:Init()
	Apollo.RegisterAddon(self)
end

---------------------------------------------------------------------------------------------------
function Hazards:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	local tSaved = self.tHazardSavedData

	return tSaved
end

function Hazards:OnRestore(eType, tSavedData)
	--[[if tSavedData then
		local tHazards = HazardsLib.GetHazardActiveList()
		self.tHazards = tHazards
		for idx, tHazard in pairs(tHazards) do
			if tSavedData[tHazard.nId] then
				self:OnHazardEnable(tHazard.nId, tSavedData[tHazard.nId])
			end
		end
	end]]--
end

function Hazards:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Hazards.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Hazards:OnDocumentReady()
	if  self.xmlDoc == nil then
		return
	end
	Apollo.RegisterEventHandler("HazardEnabled", "OnHazardEnable", self)
	Apollo.RegisterEventHandler("HazardRemoved", "OnHazardRemove", self)
	Apollo.RegisterEventHandler("HazardUpdated", "OnHazardUpdate", self)
	Apollo.RegisterEventHandler("ChangeWorld", "ClearInterface", self)

	self.tHazardWnds = {}
	self.tHazardSavedData = {}

	self.wndHazardListForm = Apollo.LoadForm(self.xmlDoc, "HazardListForm", "FixedHudStratum", self)
	self.wndHazardList = self.wndHazardListForm:FindChild("HazardList")
	self.wndHazardList:Show(true)

	-- TODO: Remove breath windows
	self.wndBreathProgressBar = self.wndHazardListForm:FindChild("Breath")
	self.wndBreathProgress = self.wndBreathProgressBar:FindChild("BreathingProgress")
	self.wndSuffocatingProgress = self.wndBreathProgressBar:FindChild("SuffocatingSprite")
	self.wndBreathProgressBar:Show(false)
	self.wndBreathProgress:Show(false)
	self.fTargetBreathLevel = 0
	self.fAdditionPerFrame = 0
	self.fCurrentBreathLevel = 100
	self.fBreathMax = 100
	self.bBreathShown = false

	self.wndHazardListForm:ArrangeChildrenVert()
end

function Hazards:ClearInterface()
	self.wndBreathProgress:Show(false)
	self.wndBreathProgressBar:Show(false)
	
	for idx, hazard in pairs(self.tHazardWnds) do
		self.wndHazardList:DestroyChildren()
	end

	self.tHazardWnds = {}
end

function Hazards:OnHazardEnable(idHazard, strDisplayTxt)
	self:BuildHazardWindow(idHazard, strDisplayTxt)
	self:OnHazardUpdate()
end

function Hazards:BuildHazardWindow(idHazard, strDisplayTxt)
	local eHazardType = nil
	for idx, tData in ipairs(HazardsLib.GetHazardActiveList()) do
		if tData.nId == idHazard then
			eHazardType = tData.eHazardType
		end
	end

	if eHazardType == HazardsLib.HazardType_Radiation or eHazardType == HazardsLib.HazardType_Temperature then -- Radiation/Temp handled in Sprint Meter Now
		return
	end

	if not self.tHazardWnds[idHazard] then
		self.tHazardWnds[idHazard] = Apollo.LoadForm(self.xmlDoc, "HazardProgressBar", self.wndHazardList, self)
		self.tHazardSavedData[idHazard] = strDisplayTxt
	end

	self:SetHazardSprites(eHazardType, self.tHazardWnds[idHazard])

	self.tHazardWnds[idHazard]:Show(true)
	self.tHazardWnds[idHazard]:FindChild("Label"):SetText(strDisplayTxt)
end

---------------------------------------------------------------------------------------------------

function Hazards:OnHazardRemove(idHazard)
	if not self.tHazardWnds[idHazard] then
		return
	end

	self.tHazardWnds[idHazard]:Show(false)
	self.tHazardWnds[idHazard]:Destroy()
	self.tHazardWnds[idHazard] = nil

	self.tHazardSavedData[idHazard] = nil

	self.wndHazardList:ArrangeChildrenVert()
end

---------------------------------------------------------------------------------------------------

function Hazards:OnHazardUpdate()
	for idx, tData in ipairs(HazardsLib.GetHazardActiveList()) do
		if not self.tHazardWnds[tData.nId] then
			self:BuildHazardWindow(tData.nId, HazardsLib.GetHazardDisplayString(tData.nId))
		end

		local idHazard = tData.nId
		local eHazardType = tData.eHazardType
		local fMeterValue = tData.fMeterValue
		local fMaxValue = tData.fMaxValue

		if self.tHazardWnds[idHazard] and eHazardType ~= HazardsLib.HazardType_Radiation and eHazardType ~= HazardsLib.HazardType_Temperature then -- Radiation/Temp handled in Sprint Meter Now
			-- find the progress bar and update the limits
			local wndProgressBar = self.tHazardWnds[idHazard]:FindChild("HazardProgress")
			wndProgressBar:SetMax(fMaxValue)

			if fMaxValue == fMeterValue then
				wndProgressBar:SetProgress(fMaxValue - .001)
			else
				wndProgressBar:SetProgress(fMeterValue)
			end

			--Cut down to integers only; we assume this is out of 100

			if eHazardType ~= HazardsLib.HazardType_Timer then -- standard percent
				local strPercent = (fMeterValue / fMaxValue) * 100
				self.tHazardWnds[idHazard]:FindChild("NumberText"):SetText(string.format("%.0f", strPercent))
			else
				local strTime = string.format("%d:%02d", math.floor(fMeterValue / 60), math.floor(fMeterValue % 60))
				self.tHazardWnds[idHazard]:FindChild("NumberText"):SetText(strTime)
			end

			wndProgressBar:Show(true)
			wndProgressBar:SetTooltipType(Window.TPT_OnCursor)
			wndProgressBar:SetTooltip(tData.strTooltip)

			self:SetHazardSprites(eHazardType, self.tHazardWnds[idHazard])
		end
	end

	self.wndHazardList:ArrangeChildrenVert()
end

function Hazards:SetHazardSprites(eHazardType, wndHazard)
	local tSprites = karBarSprites[eHazardType] or karBarSprites["default"]

	wndHazard:FindChild("Icon"):SetSprite(tSprites.strIcon)
	wndHazard:FindChild("HazardProgress"):SetFillSprite(tSprites.strFillColor)
	wndHazard:FindChild("HazardProgress"):SetGlowSprite(tSprites.strEdgeColor)
end

local HazardInst = Hazards:new()
HazardInst:Init()