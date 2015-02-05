-----------------------------------------------------------------------------------------------
-- Client Lua Script for MalgraveAdventureResources
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

-----------------------------------------------------------------------------------------------
-- MalgraveAdventureResources Module Definition
-----------------------------------------------------------------------------------------------
local MalgraveAdventureResources = {}

local knSaveVersion = 1

function MalgraveAdventureResources:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here
	self.nFatigueMax = 75
	self.nFoodMax = 100
	self.nWaterMax = 100
	self.nFodderMax = 100
	self.nFatigueDisplayMax = 100
	self.nMembersMax = 30

    return o
end

function MalgraveAdventureResources:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return false
	end
	
	local tSave = 
	{
		tAdventureInfo = self.tAdventureInfo,
		nSaveVersion = knSaveVersion,
	}
	
	tSave.tAdventureInfo.nSaveVersion = knSaveVersion
	tSave.tAdventureInfo.nFatigueMax = self.nFatigueMax
	
	return tSave
end

function MalgraveAdventureResources:OnRestore(eType, tSavedData)
	if not tSavedData or tSavedData.nSaveVersion ~= knSaveVersion then
		return
	end
	
	local bIsMalgraveAdventure = false
	local tActiveEvents = PublicEvent.GetActiveEvents()
	
	for idx, peEvent in pairs(tActiveEvents) do
		if peEvent:GetEventType() == PublicEvent.PublicEventType_Adventure_Malgrave then
			bIsMalgraveAdventure = true
			break
		end
	end
	
	self.tAdventureInfo = {}
	if bIsMalgraveAdventure and tSavedData and tSavedData.tAdventureInfo.bIsShown then
		self:Initialize()
		self:OnSet(tSavedData.nResourceMax, tSavedData.nFatigueMax)
		self:OnUpdate(tSavedData.tAdventureInfo.nFatigue, tSavedData.tAdventureInfo.nFood, tSavedData.tAdventureInfo.nWater, tSavedData.tAdventureInfo.nFodder, tSavedData.tAdventureInfo.nMembers)
	end
end

function MalgraveAdventureResources:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- MalgraveAdventureResources OnLoad
-----------------------------------------------------------------------------------------------
function MalgraveAdventureResources:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("AdventureMalgrave.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function MalgraveAdventureResources:OnDocumentReady()
    Apollo.RegisterEventHandler("AdvMalgraveResourceSet", "OnSet", self)
	Apollo.RegisterEventHandler("ChangeWorld", "OnHide", self)
	Apollo.RegisterEventHandler("AdvMalgraveHideResource", "OnHide", self)
	Apollo.RegisterSlashCommand("malgraveres", "Initialize", self)
	Apollo.RegisterEventHandler("AdvMalgraveShowResource", "Initialize", self)
    Apollo.RegisterEventHandler("AdvMalgraveUpdateResource", "OnUpdate", self)
	
	if not self.tAdventureInfo then
		self.tAdventureInfo = {}
	end
end

function MalgraveAdventureResources:Initialize()
	if not self.wndMain or not self.wndMain:IsValid() then
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "MalgraveAdventureResourcesForm", nil, self)
		Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("Lore_Malgrave")})
		
		self.timerMaxProgressFalshIcon = ApolloTimer.Create(8, false, "OnMaxProgressFlashIcon", self)
		self.timerMaxProgressFalshIcon:Stop()
		self.wndMain:FindChild("LeftAssetCostume"):SetCostumeToCreatureId(19195) -- TODO Hardcoded
		self.wndMain:FindChild("LeftAssetCostume"):SetModelSequence(150)
	
		self.wndMain:Show(true)
		self.tAdventureInfo.bIsShown = true
	end
end

function MalgraveAdventureResources:OnHide()
	if self.wndMain then
		self.wndMain:Destroy()
		self.wndMain = nil
		self.tAdventureInfo.bIsShown = false
	end
end

function MalgraveAdventureResources:OnUpdate(nFatigue, nFood, nWater, nFodder, nMembers)
	if not self.wndMain or not self.wndMain:IsValid() then
		self:Initialize()
	end
	
	local wndSubBars = self.wndMain:FindChild("SubBars")
	local wndFoodContainer = wndSubBars:FindChild("FoodBarBG")
	local wndWaterContainer = wndSubBars:FindChild("WaterBarBG")
	local wndFeedContainer = wndSubBars:FindChild("FeedBarBG")
	local wndFatigueContainer = self.wndMain:FindChild("FatigueBarBG")

	local tArgList = { nFood, nWater, nFodder }
	for idx, wndCurr in pairs({ wndFoodContainer:FindChild("FoodProgressBar"), wndWaterContainer:FindChild("WaterProgressBar"), wndFeedContainer:FindChild("FeedProgressBar") }) do
		local nNewValue = tArgList[idx]
		local nPrevValue = wndCurr:FindChild("ProgressFlashIcon"):GetData()
		if nPrevValue and nNewValue ~= 0 then
			self.timerMaxProgressFalshIcon:Start()

			wndCurr:FindChild("ProgressFlashIcon"):Show(nNewValue > nPrevValue or wndCurr:FindChild("ProgressFlashIcon"):IsShown())
			if nNewValue - nPrevValue > 0 then
				wndCurr:FindChild("ProgressFlashIcon"):SetText("+"..nNewValue - nPrevValue)
			end
		end
	end

	local nFatiguePercent = ((nFatigue / self.nFatigueMax) * 100)
	self:SetBarValueAndData(wndFoodContainer:FindChild("FoodProgressBar"), nFood, self.nFoodMax)
	self:SetBarValueAndData(wndWaterContainer:FindChild("WaterProgressBar"), nWater, self.nWaterMax)
	self:SetBarValueAndData(wndFeedContainer:FindChild("FeedProgressBar"), nFodder, self.nFodderMax)
	self:SetBarValueAndData(wndFatigueContainer:FindChild("FatigueProgressBar"), nFatiguePercent, self.nFatigueDisplayMax)
	wndFoodContainer:FindChild("FoodProgressText"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), nFood, self.nFoodMax))
	wndWaterContainer:FindChild("WaterProgressText"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), nWater, self.nWaterMax))
	wndFeedContainer:FindChild("FeedProgressText"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), nFodder, self.nFodderMax))
	wndFatigueContainer:FindChild("FatigueProgressText"):SetText(String_GetWeaselString(Apollo.GetString("CRB_Percent"), nFatiguePercent))
	self.wndMain:FindChild("SurvivorCountText"):SetText(String_GetWeaselString(Apollo.GetString("Achievements_ProgressBarProgress"), nMembers, self.nMembersMax))
	
	self.tAdventureInfo.nFatigue = nFatigue
	self.tAdventureInfo.nFood = nFood
	self.tAdventureInfo.nWater = nWater
	self.tAdventureInfo.nFodder = nFodder
	self.tAdventureInfo.nMembers = nMembers
end

function MalgraveAdventureResources:OnSet(nMax, nFatigue)
	self.nFoodMax = nMax
	self.nWaterMax = nMax
	self.nFodderMax = nMax
	self.nFatigueMax = nFatigue
end

function MalgraveAdventureResources:SetBarValueAndData(wndBar, nValue, nMax)
	if nMax then
		wndBar:SetMax(nMax)
	end

	wndBar:SetProgress(nValue)
	wndBar:SetData(nValue)

	if wndBar:FindChild("ProgressFlashIcon") and not wndBar:FindChild("ProgressFlashIcon"):IsShown() then -- This will accumulate +1+1+1's into +3s
		wndBar:FindChild("ProgressFlashIcon"):SetData(nValue) -- Note fatigue bar doesn't save, but that's fine for now
	end
end

function MalgraveAdventureResources:OnMaxProgressFlashIcon()
	if self.wndMain and self.wndMain:IsValid() then
		self.timerMaxProgressFalshIcon:Stop()
		for idx, wndCurr in pairs({ self.wndMain:FindChild("SubBars:FoodBarBG:FoodProgressBar"), self.wndMain:FindChild("SubBars:WaterBarBG:WaterProgressBar"), self.wndMain:FindChild("SubBars:FeedBarBG:FeedProgressBar") }) do
			wndCurr:FindChild("ProgressFlashIcon"):Show(false)
			self:SetBarValueAndData(wndCurr, wndCurr:GetData()) -- After show false, will get ProgressFlashIcon's data too
		end
	end
end

-----------------------------------------------------------------------------------------------
-- MalgraveAdventureResources Instance
-----------------------------------------------------------------------------------------------
local MalgraveAdventureResourcesInst = MalgraveAdventureResources:new()
MalgraveAdventureResourcesInst:Init()
ient="1" IfHoldNoSignal="1" DT_VCENTER="1" DT_CENTER="1" LAnchorPoint="0.5" LAnchorOffset="-21" TAnchorPoint="0.5" TAnchorOffset="-28" RAnchorPoint="0.5" RAnchorOffset="15" BAnchorPoint="0.5" BAnchorOffset="20" NeverBringToFront="1" Picture="0" WindowSoundTemplate="ActionBarButton" BGColor="white" TextColor="white" IgnoreMouse="0" TooltipType="OnCursor" IgnoreTooltipDelay="1" TooltipColor="" DrawShortcutBottom="1">
            <Event Name="GenerateTooltip" Function="OnGenerateTooltip"/>
        </Control>
    </Form>
</Forms>
tion.tCenter.nX) / (#arRow + 1)
				arRow[#arRow + 1] = self.tActionBarsHorz[nOtherBar]
			end
		end
	end

	-- if there were any overlapping then rearrange all of them
	if #arRow > 1 then
		local kOverlap = 4

		local nLeft = nRowX - nRowWidth / 2
		local tDisplay = Apollo.GetDisplaySize()
		if tDisplay and tDisplay.nWidth then
			if nLeft + nRowWidth > tDisplay.nWidth / 2 then
				nLeft = nRowWidth / -2
			end
		end
		nLeft = nLeft + kOverlap * #arRow

		for nIdx, nTmpBar in pairs(arRow) do
			local tTmpPosition = self:GetBarPosition(nTmpBar)
			self:SetBarPosition(nTmpBar, nil, { nX = nLeft + tTmpPosition.tSize.nWidth / 2 } )
			nLeft = nLeft + tTmpPosition.tSize.nWidth - kOverlap
		end
	end
end

function ActionBarShortcut:ShowBarFloatVert(nBar, bIsVisible, nShortcuts)
	-- set the position of this action bar ignoring overlapping
	self:SetBarPosition( self.tActionBarsVert[nBar], { nHeight = (nShortcuts * 60) + 116 } )

	local tPosition = self:GetBarPosition(self.tActionBarsVert[nBar])

	-- collect all overlapping bars
	local arRow = { nBar }
	local nRowHeight = tPosition.tSize.nHeight
	local nRowY = tPosition.tCenter.nY
	for nOtherBar,tActionBar in pairs(self.tActionBarsVert) do
		if nOtherBar ~= nBar and tActionBar:IsShown() then
			local tOtherPosition = self:GetBarPosition(nOtherBar)

			if tOtherPosition and tOtherPosition.tCenter and tOtherPosition.tCenter.nX == tPosition.tCenter.nX then
				nRowHeight = nRowHeight + tOtherPosition.tSize.nHeight
				nRowY = (nRowY * #arRow + tOtherPosition.tCenter.nY) / (#arRow + 1)
				arRow[#arRow + 1] = self.tActionBarsVert[nOtherBar]
			end
		end
	end

	-- if there were any overlapping then rearrange all of them
	if #arRow > 1 then
		local kOverlap = 4

		local nTop = nRowY - nRowHeight / 2
		local tDisplay = Apollo.GetDisplaySize()
		if tDisplay and tDisplay.nWidth then
			if nTop + nRowHeight > tDisplay.nWidth / 2 then
				nTop = nRowHeight / -2
			end
		end
		nTop = nTop + kOverlap * #arRow

		for nIdx, nTmpBar in pairs(arRow) do
			local tTmpPosition = self:GetBarPosition(nTmpBar)
			self:SetBarPosition(nTmpBar, nil, { nY = nTop + tTmpPosition.tSize.nHeight / 2 } )
			nTop = nTop + tTmpPosition.tSize.nHeight - kOverlap
		end
	end
end

function ActionBarShortcut:ShowWindow(nBar, bIsVisible, nShortcuts)
    if self.tActionBarsHorz[nBar] == nil then
		return
	end
	
	self.tActionBarSettings[nBar] = {}
	self.tActionBarSettings[nBar].bIsVisible = bIsVisible
	self.tActionBarSettings[nBar].nShortcuts = nShortcuts

	if nShortcuts and bIsVisible then
		--self:ShowBarDocked(nBar, bIsVisible, nShortcuts)
		self:ShowBarFloatHorz(nBar, bIsVisible, nShortcuts)
		self:ShowBarFloatVert(nBar, bIsVisible, nShortcuts)
	end
	
	if not self.bTimerRunning then
		self.timerShorcutArt:Start()
		self.bTimerRunning = true
	end

	self.tActionBars[nBar]:Show(bIsVisible and self.bDocked, not bIsVisible)
	self.tActionBarsHorz[nBar]:Show(bIsVisible and not self.bDocked and self.bHorz, not bIsVisible)
	self.tActionBarsVert[nBar]:Show(bIsVisible and not self.bDocked and not self.bHorz, not bIsVisible)
end

function ActionBarShortcut:OnActionBarShortcutArtTimer()
	self.bTimerRunning = false
	local bBarVisible = false

	for nbar, tSettings in pairs(self.tActionBarSettings) do
		bBarVisible = bBarVisible or (tSettings.bIsVisible and self.bDocked)
	end
	
	Event_FireGenericEvent("ShowActionBarShortcutDocked", bBarVisible)
end

function 