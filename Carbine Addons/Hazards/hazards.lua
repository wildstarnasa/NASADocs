require "Window"
require "HazardsLib"

---------------------------------------------------------------------------------------------------

--Hazards
local Hazards = {}

local karBarSprites =  -- overall array; each table's formatting is icon, fill, edge
{
	General = 		{strIcon = "kitIcon_Gold_HazardGeneral", 		strFillColor = "kitIProgBar_HoloFrame_FillRed", 	strEdgeColor = "kitIProgBar_HoloFrame_CapRed"},
	Radiation = 	{strIcon = "kitIcon_Gold_HazardRadioactive", 	strFillColor = "kitIProgBar_HoloFrame_FillRed", 	strEdgeColor = "kitIProgBar_HoloFrame_CapRed"},
	Temperature = 	{strIcon = "kitIcon_Gold_HazardTemperature", 	strFillColor = "kitIProgBar_HoloFrame_FillBlue", 	strEdgeColor = "kitIProgBar_HoloFrame_CapRed"},
	Proximity = 	{strIcon = "kitIcon_Gold_HazardObserver", 		strFillColor = "kitIProgBar_HoloFrame_FillBlue", 	strEdgeColor = "kitIProgBar_HoloFrame_CapArrowR"},
	Timer = 		{strIcon = "kitIcon_Gold_HazardProximity", 		strFillColor = "kitIProgBar_HoloFrame_FillBlue", 	strEdgeColor = "kitIProgBar_HoloFrame_CapArrowL"},
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

	Apollo.RegisterEventHandler("BreathChanged", "OnBreathChanged", self)
	Apollo.RegisterEventHandler("Breath_FlashEvent", "OnFlash", self)
	Apollo.RegisterTimerHandler("OutOfWaterUpdate", "OnFrame", self)
	
	-- Not pretty, but only way to stop timer after breath is at max
	Apollo.CreateTimer("OutOfWaterUpdate", 0.03, false)

	self.tHazardWnds = {}
	self.tHazardSavedData = {}
	

	-- container of all progress bars
	self.wndHazardListForm = Apollo.LoadForm(self.xmlDoc, "HazardListForm", "FixedHudStratum", self)
	self.wndHazardList = self.wndHazardListForm:FindChild("HazardList")
	self.wndHazardList:Show(true)

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

---------------------------------------------------------------------------------------------------
-- Breath
---------------------------------------------------------------------------------------------------
function Hazards:ClearInterface()
	self.wndBreathProgress:Show(false)
	self.wndBreathProgressBar:Show(false)
	for idx, hazard in pairs(self.tHazardWnds) do
		self.wndHazardList:DestroyChildren()
	end
	
	self.tHazardWnds = {}
end
  
---------------------------------------------------------------------------------------------------

function Hazards:OnFrame()
	if 	self.bBreathShown ~= self.wndBreathProgress:IsVisible() then
		self.bBreathShown = self.wndBreathProgress:IsVisible()
		self.wndHazardListForm:ArrangeChildrenVert()
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer == nil then
		self.wndBreathProgressBar:Show(false)
	else
		if unitPlayer:ShouldShowBreathBar() == true or
			(self.fAdditionPerFrame ~= 0 and self.fCurrentBreathLevel ~= self.fTargetBreathLevel) then
			self:SetRemainingBreath( )
			Apollo.StartTimer("OutOfWaterUpdate")
		else
			if self.wndBreathProgress:IsVisible() then
				self.wndBreathProgressBar:Show(false)
				self.wndBreathProgress:Show(false)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------

function Hazards:OnBreathChanged( fBreath, fBreathMax )
	if fBreath == fBreathMax then
		self.wndBreathProgressBar:Show(false)
		return
	end
	
	self.fTargetBreathLevel = math.floor(fBreath)

	local fAddition = fBreath - self.fCurrentBreathLevel
	if fAddition <= -1 then 
		fAddition = -1 
	end
	if fAddition > 1 then 
		fAddition = 1
	end
	self.fAdditionPerFrame = fAddition

	-- when the window fist shows, make sure tot just set the current value
	if not self.wndBreathProgress:IsVisible() then
		self.fCurrentBreathLevel = self.fTargetBreathLevel
	end

	self:OnFrame()
end

---------------------------------------------------------------------------------------------------

function Hazards:SetRemainingBreath( )
	if self.fCurrentBreathLevel ~= self.fTargetBreathLevel then
		self.fCurrentBreathLevel = self.fCurrentBreathLevel + self.fAdditionPerFrame

		if self.fAdditionPerFrame < 0 then
			if self.fCurrentBreathLevel < self.fTargetBreathLevel then
				self.fAdditionPerFrame = 0
				self.fCurrentBreathLevel = self.fTargetBreathLevel
			end
		end

		if self.fAdditionPerFrame > 0 then
			if self.fCurrentBreathLevel > self.fTargetBreathLevel then
				self.fAdditionPerFrame = 0
				self.fCurrentBreathLevel = self.fTargetBreathLevel
			end
		end
	end

	local fBreath = math.floor(self.fCurrentBreathLevel)
	if GameLib.GetPlayerUnit() then
		self.wndBreathProgressBar:FindChild("NumberText"):SetText(math.max(0, fBreath - 1))
		self.wndBreathProgress:SetMax(self.fBreathMax)
		self.wndBreathProgress:SetProgress(fBreath)
		self.wndBreathProgressBar:Show(true)
		self.wndBreathProgress:Show(true)
	end
end

---------------------------------------------------------------------------------------------------

function Hazards:OnFlash( nHealthPercentage )
	self.wndSuffocatingProgress:SetSprite("sprNp_WhiteBarFlash")
end


---------------------------------------------------------------------------------------------------
-- Hazards
---------------------------------------------------------------------------------------------------

function Hazards:OnHazardEnable(idHazard, strDisplayTxt)
	self:BuildHazardWindow(idHazard, strDisplayTxt)
	self:OnHazardUpdate()
end

---------------------------------------------------------------------------------------------------

function Hazards:BuildHazardWindow(idHazard, strDisplayTxt)
	if not self.tHazardWnds[idHazard] then
		self.tHazardWnds[idHazard] = Apollo.LoadForm(self.xmlDoc, "HazardProgressBar", self.wndHazardList, self)
		self.tHazardSavedData[idHazard] = strDisplayTxt
	end

	-- initial format
	local tHazards = HazardsLib.GetHazardActiveList()
	local eHazardType
	for idx, tData in ipairs(tHazards) do
		if tData.nId == idHazard then
			eHazardType = tData.eHazardType
		end
	end

	local tSprites = karBarSprites.General
	if eHazardType == HazardsLib.HazardType_Radiation then
		tSprites = karBarSprites.Radiation
	elseif eHazardType == HazardsLib.HazardType_Temperature then
		tSprites = karBarSprites.Temperature
	elseif eHazardType == HazardsLib.HazardType_Proximity then
		tSprites = karBarSprites.Proximity
	elseif eHazardType == HazardsLib.HazardType_Timer then
		tSprites = karBarSprites.Timer
	end

	self.tHazardWnds[idHazard]:FindChild("Icon"):SetSprite(tSprites[1])
	self.tHazardWnds[idHazard]:FindChild("HazardProgress"):SetFillSprite(tSprites[2])
	self.tHazardWnds[idHazard]:FindChild("HazardProgress"):SetGlowSprite(tSprites[3])

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
	local tHazards = HazardsLib.GetHazardActiveList()
	for idx, tData in ipairs(tHazards) do
		if not self.tHazardWnds[tData.nId] then
			self:BuildHazardWindow(tData.nId, HazardsLib.GetHazardDisplayString(tData.nId))
		end
		
		local idHazard = tData.nId
		local eHazardType = tData.eHazardType

		local fMeterValue = tData.fMeterValue
		local fMaxValue = tData.fMaxValue
		
		--if not self.tHazardWnds[tData.nId]:Shown() then
			

		-- make sure the window is enabled
		if self.tHazardWnds[idHazard] then
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

			local tSprites = karBarSprites.General
			if eHazardType == HazardsLib.HazardType_Radiation then
				tSprites = karBarSprites.Radiation
			elseif eHazardType == HazardsLib.HazardType_Temperature then
				tSprites = karBarSprites.Temperature
			elseif eHazardType == HazardsLib.HazardType_Proximity then
				tSprites = karBarSprites.Proximity
			elseif eHazardType == HazardsLib.HazardType_Timer then
				tSprites = karBarSprites.Timer
			end

			self.tHazardWnds[idHazard]:FindChild("Icon"):SetSprite(tSprites[1])
			self.tHazardWnds[idHazard]:FindChild("HazardProgress"):SetFillSprite(tSprites[2])
			self.tHazardWnds[idHazard]:FindChild("HazardProgress"):SetGlowSprite(tSprites[3])
		end
	end

	self.wndHazardList:ArrangeChildrenVert()
end

---------------------------------------------------------------------------------------------------

local HazardInst = Hazards:new()
HazardInst:Init()